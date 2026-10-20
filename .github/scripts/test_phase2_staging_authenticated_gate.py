"""Network-free regression tests for the Phase 2 staging-only JWT/RLS gate."""
import contextlib
import io
import os
import unittest
from unittest.mock import patch

import phase2_staging_authenticated_gate as gate


ENV = {
    "SUKUN_STAGE_GATE_CONFIRM": "STAGING_ONLY",
    "SUKUN_STAGE_PROJECT_REF": gate.STAGING_REF,
    "SUKUN_STAGE_PUBLISHABLE_KEY": "sb_publishable_test_only",
    "SUKUN_STAGE_PATIENT_A_ID": "QA-A",
    "SUKUN_STAGE_PATIENT_A_PASSWORD": "synthetic-a",
    "SUKUN_STAGE_PATIENT_B_ID": "QA-B",
    "SUKUN_STAGE_PATIENT_B_PASSWORD": "synthetic-b",
    "SUKUN_STAGE_ADMIN_EMAIL": "admin@invalid.test",
    "SUKUN_STAGE_ADMIN_PASSWORD": "synthetic-admin",
    "SUKUN_STAGE_MEMBER_EMAIL": "member@invalid.test",
    "SUKUN_STAGE_MEMBER_PASSWORD": "synthetic-member",
}
IDENTITIES = {"token-A": "uid-A", "token-B": "uid-B",
              "token-admin": "uid-admin", "token-member": "uid-member"}
ROLES = {"token-A": "patient", "token-B": "patient",
         "token-admin": "super_admin", "token-member": "member"}
OWNED = {
    "care_plans": "plan-A",
    "patients": "patient-A",
    "prescriptions": "rx-A",
    "task_instances": "task-A",
    "task_completions": "completion-A",
}


def fake_api(path, key, *, bearer=None, payload=None, params=None, leak=False):
    if path == "/functions/v1/patient-sign-in":
        return 200, {"refresh_token": "refresh-A" if payload["identifier"] == "QA-A"
                     else "refresh-B"}
    if path == "/auth/v1/token?grant_type=refresh_token":
        return 200, {"access_token": "token-A" if payload["refresh_token"] == "refresh-A"
                     else "token-B"}
    if path == "/auth/v1/token?grant_type=password":
        return 200, {"access_token": "token-admin"
                     if payload["email"] == "admin@invalid.test" else "token-member"}
    if path == "/auth/v1/user":
        return 200, {"id": IDENTITIES[bearer]}
    if path == "/rest/v1/user_roles":
        return 200, [{"role": ROLES[bearer]}]
    if path.startswith("/rest/v1/"):
        table = path.rsplit("/", 1)[-1]
        if bearer == "token-A":
            return 200, [{"id": OWNED[table]}]
        if bearer == "token-admin":
            return 200, [{"id": OWNED[table]}]
        if leak and bearer == "token-B" and table == "care_plans":
            return 200, [{"id": OWNED[table]}]
        return 200, []
    raise AssertionError("Unexpected synthetic endpoint")


class StagingGateTests(unittest.TestCase):
    def test_missing_secrets_fail_closed_before_any_network_request(self):
        with patch.dict(os.environ, {
            "SUKUN_STAGE_GATE_CONFIRM": "STAGING_ONLY",
            "SUKUN_STAGE_PROJECT_REF": gate.STAGING_REF,
        }, clear=True):
            with patch.object(gate, "request_json") as api:
                with self.assertRaisesRegex(gate.GateFailure, "secrets missing"):
                    gate.run()
                api.assert_not_called()

    def test_refuses_non_staging_project_before_network(self):
        wrong = dict(ENV, SUKUN_STAGE_PROJECT_REF="vydfafumxptanpkmtrpr")
        with patch.dict(os.environ, wrong, clear=True):
            with patch.object(gate, "request_json") as api:
                with self.assertRaisesRegex(gate.GateFailure, "Incorrect staging"):
                    gate.run()
                api.assert_not_called()

    def test_full_synthetic_role_gate_passes_without_writes(self):
        paths = []
        def fake(path, key, *, bearer=None, payload=None, params=None):
            paths.append(path)
            return fake_api(path, key, bearer=bearer, payload=payload, params=params)
        with patch.dict(os.environ, ENV, clear=True):
            with patch.object(gate, "request_json", side_effect=fake):
                with contextlib.redirect_stdout(io.StringIO()) as out:
                    gate.run()
                self.assertIn("PASS: read-only live JWT/RLS staging gate", out.getvalue())
        self.assertFalse(any("/rest/v1/rpc/" in p for p in paths))
        self.assertIn("/rest/v1/care_plans", paths)

    def test_cross_patient_visible_row_blocks_release(self):
        with patch.dict(os.environ, ENV, clear=True):
            def leaking_api(path, key, *, bearer=None, payload=None, params=None):
                return fake_api(path, key, bearer=bearer, payload=payload,
                                params=params, leak=True)
            with patch.object(gate, "request_json", side_effect=leaking_api):
                with contextlib.redirect_stdout(io.StringIO()):
                    with self.assertRaisesRegex(gate.GateFailure, "SECURITY"):
                        gate.run()

    def test_explicit_anonymous_denial_is_accepted(self):
        with patch.object(gate, "request_json", return_value=(403, None)):
            self.assertEqual(
                gate.rows("public-key", None, "care_plans", allow_denial=True),
                [],
            )


if __name__ == "__main__":
    unittest.main()
