#!/usr/bin/env python3
"""Read-only real-JWT staging role/RLS acceptance. Never run against Production.

All credentials are synthetic and supplied by masked GitHub Actions secrets.
Only pass/fail step labels appear in output. No raw HTTP errors, tokens,
identifiers, patient fields, URLs containing row IDs, or response bodies.
This is an authenticated REST gate, NOT a Flutter browser UI acceptance test.
"""
import json
import os
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

STAGING_REF = "qacklgqvxvjjzsimjoip"
STAGING_URL = "https://" + STAGING_REF + ".supabase.co"


class GateFailure(Exception):
    """Safe diagnostic: never contain secrets, identities or API responses."""


def require(ok, safe_label):
    if not ok:
        raise GateFailure(safe_label)


def request_json(path, key, *, bearer=None, payload=None, params=None):
    target = STAGING_URL + path
    if params:
        target += "?" + urlencode(params)
    headers = {"apikey": key, "Accept": "application/json"}
    if bearer:
        headers["Authorization"] = "Bearer " + bearer
    if payload is not None:
        headers["Content-Type"] = "application/json"
    req = Request(
        target,
        headers=headers,
        data=json.dumps(payload).encode("utf-8") if payload is not None else None,
        method="POST" if payload is not None else "GET",
    )
    try:
        with urlopen(req, timeout=25) as res:
            body = res.read(256 * 1024)
            return res.status, json.loads(body)
    except HTTPError as exc:
        # Never read/log response body (may disclose account or tokens).
        return exc.code, None
    except (URLError, TimeoutError, ValueError):
        raise GateFailure("Staging API connection or JSON response unavailable") from None


def login_patient(key, identifier, password):
    status, data = request_json(
        "/functions/v1/patient-sign-in", key,
        payload={"identifier": identifier, "password": password},
    )
    require(status == 200 and isinstance(data, dict), "Synthetic Patient login rejected")
    refresh = data.get("refresh_token")
    require(isinstance(refresh, str) and refresh, "Patient refresh token missing")
    status, session = request_json(
        "/auth/v1/token?grant_type=refresh_token", key,
        payload={"refresh_token": refresh},
    )
    require(status == 200 and isinstance(session, dict), "Patient token exchange failed")
    token = session.get("access_token")
    require(isinstance(token, str) and token, "Patient access token unavailable")
    return token


def login_email(key, email, password, role_label):
    status, data = request_json(
        "/auth/v1/token?grant_type=password", key,
        payload={"email": email, "password": password},
    )
    require(status == 200 and isinstance(data, dict), role_label + " login rejected")
    token = data.get("access_token")
    require(isinstance(token, str) and token, role_label + " access token missing")
    return token


def get_user_id(key, token, label):
    status, user = request_json("/auth/v1/user", key, bearer=token)
    require(status == 200 and isinstance(user, dict), label + " token invalid")
    user_id = user.get("id")
    require(isinstance(user_id, str) and user_id, label + " identity missing")
    return user_id


def rows(key, token, table, params=None, *, allow_denial=False):
    query = {"select": "id", "limit": "100"}
    if params:
        query.update(params)
    status, data = request_json(
        "/rest/v1/" + table, key, bearer=token, params=query,
    )
    if allow_denial and status in (401, 403):
        return []
    require(status == 200 and isinstance(data, list), "Clinical read failed: " + table)
    return data


def roles(key, token, user_id):
    status, data = request_json(
        "/rest/v1/user_roles", key, bearer=token,
        params={"select": "role", "user_id": "eq." + user_id},
    )
    require(status == 200 and isinstance(data, list), "Verified role lookup failed")
    return {r.get("role") for r in data}


def first_id(data, label):
    require(len(data) > 0 and isinstance(data[0].get("id"), str), label)
    return data[0]["id"]


def run():
    mode = os.getenv("SUKUN_STAGE_GATE_MODE", "FULL")
    require(mode in ("PATIENT_ONLY", "FULL"), "Invalid staging gate mode")
    required = (
        "SUKUN_STAGE_PUBLISHABLE_KEY",
        "SUKUN_STAGE_PATIENT_A_ID", "SUKUN_STAGE_PATIENT_B_ID",
    )
    if mode == "FULL":
        required += (
            "SUKUN_STAGE_ADMIN_EMAIL", "SUKUN_STAGE_ADMIN_PASSWORD",
            "SUKUN_STAGE_MEMBER_EMAIL", "SUKUN_STAGE_MEMBER_PASSWORD",
        )
    shared_password = os.getenv("SUKUN_STAGE_PATIENT_SHARED_PASSWORD")
    if not shared_password:
        required += (
            "SUKUN_STAGE_PATIENT_A_PASSWORD",
            "SUKUN_STAGE_PATIENT_B_PASSWORD",
        )
    require(os.getenv("SUKUN_STAGE_GATE_CONFIRM") == "STAGING_ONLY",
            "Explicit staging-only confirmation missing")
    missing = [name for name in required if not os.getenv(name)]
    require(not missing, "Synthetic staging QA secrets missing; configure repository Actions secrets")
    key = os.environ["SUKUN_STAGE_PUBLISHABLE_KEY"]
    require(key.startswith("sb_publishable_"), "A public staging publishable key is required")
    require(os.getenv("SUKUN_STAGE_PROJECT_REF") == STAGING_REF,
            "Incorrect staging project reference")
    if mode == "FULL":
        for item in ("SUKUN_STAGE_ADMIN_EMAIL", "SUKUN_STAGE_MEMBER_EMAIL"):
            require("@" in os.environ[item], "Admin/Member QA login must use synthetic email")

    a = login_patient(key, os.environ["SUKUN_STAGE_PATIENT_A_ID"],
                      shared_password or os.environ["SUKUN_STAGE_PATIENT_A_PASSWORD"])
    b = login_patient(key, os.environ["SUKUN_STAGE_PATIENT_B_ID"],
                      shared_password or os.environ["SUKUN_STAGE_PATIENT_B_PASSWORD"])
    user_ids = [
        get_user_id(key, a, "Patient A"),
        get_user_id(key, b, "Patient B"),
    ]
    require(len(set(user_ids)) == 2, "Patient A/B must be distinct accounts")
    require(os.environ["SUKUN_STAGE_PATIENT_A_ID"] !=
            os.environ["SUKUN_STAGE_PATIENT_B_ID"],
            "Patient A/B identifiers must be distinct")
    for label, token, user_id in (
        ("Patient A", a, user_ids[0]),
        ("Patient B", b, user_ids[1]),
    ):
        require(roles(key, token, user_id) == {"patient"},
                "Unexpected or privileged role for staging " + label)
    print("PASS: two distinct synthetic Patient accounts authenticated with server roles")

    if mode == "FULL":
        admin = login_email(key, os.environ["SUKUN_STAGE_ADMIN_EMAIL"],
                            os.environ["SUKUN_STAGE_ADMIN_PASSWORD"], "Admin")
        member = login_email(key, os.environ["SUKUN_STAGE_MEMBER_EMAIL"],
                             os.environ["SUKUN_STAGE_MEMBER_PASSWORD"], "Member")
        admin_id = get_user_id(key, admin, "Admin")
        member_id = get_user_id(key, member, "Member")
        require(len(set(user_ids + [admin_id, member_id])) == 4,
                "All staging accounts must have distinct Auth users")
        require(roles(key, admin, admin_id) == {"super_admin"},
                "Staging Admin role not verified or has extra roles")
        require(roles(key, member, member_id) == {"member"},
                "Staging Member role not verified or has extra roles")
        print("PASS: distinct Admin/Member authenticated with server roles")

    a_patients = rows(key, a, "patients")
    b_patients = rows(key, b, "patients")
    require(len(a_patients) == 1, "Patient A must read exactly one own synthetic record")
    require(len(b_patients) == 1, "Patient B must read exactly one own synthetic record")
    a_patient = first_id(a_patients, "Patient A identity unavailable")
    b_patient = first_id(b_patients, "Patient B identity unavailable")
    require(a_patient != b_patient, "Patient accounts share a patient record")
    a_plans = rows(key, a, "care_plans",
                   {"status": "eq.active", "patient_id": "eq." + a_patient})
    require(len(a_plans) == 1, "Patient A requires exactly one own active plan")
    a_plan = first_id(a_plans, "Patient A plan ID unavailable")
    require(len(rows(key, b, "care_plans")) == 0,
            "Patient B must have no visible plan in this synthetic fixture")
    require(len(rows(key, b, "patients", {"id": "eq." + a_patient})) == 0,
            "SECURITY: Patient B can read Patient A identity")
    require(len(rows(key, a, "patients", {"id": "eq." + b_patient})) == 0,
            "SECURITY: Patient A can read Patient B identity")
    require(len(rows(key, b, "care_plans", {"id": "eq." + a_plan})) == 0,
            "SECURITY: Patient B can read Patient A care_plans")
    for table in ("prescriptions", "task_instances", "task_completions"):
        owned = rows(key, a, table, {"patient_id": "eq." + a_patient})
        target = first_id(owned, "Patient A requires a synthetic fixture in " + table)
        require(len(rows(key, b, table, {"id": "eq." + target})) == 0,
                "SECURITY: Patient B can read Patient A " + table)
    actions = rows(key, a, "plan_actions", {"care_plan_id": "eq." + a_plan})
    a_action = first_id(actions, "Patient A requires an approved plan action fixture")
    require(len(rows(key, b, "plan_actions", {"id": "eq." + a_action})) == 0,
            "SECURITY: Patient B can read Patient A plan_actions")
    print("PASS: authenticated Patients have distinct, complete clinical fixtures and no cross-patient reads")

    if mode == "FULL":
        require(len(rows(key, admin, "care_plans", {"id": "eq." + a_plan})) == 1,
                "Admin cannot read synthetic Patient A plan")
    for table in ("patients", "care_plans", "prescriptions", "plan_actions",
                  "task_instances", "task_completions"):
        if mode == "FULL":
            require(len(rows(key, member, table)) == 0,
                    "SECURITY: General Member can read " + table)
        require(len(rows(key, None, table, allow_denial=True)) == 0,
                "SECURITY: Guest can read " + table)
    if mode == "FULL":
        print("PASS: Admin clinical read, Member and Guest clinical denial")
    else:
        print("PASS: Patient-only gate; Admin/Member login checks remain pending")
    print("PASS: read-only live JWT/RLS staging gate; no writes performed")


def main():
    try:
        run()
    except GateFailure as exc:
        print("FAIL: " + str(exc), file=sys.stderr)
        return 1
    except Exception:
        # Unexpected client errors must not print URLs/body/token/credentials.
        print("FAIL: unexpected staging gate error (details suppressed)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
