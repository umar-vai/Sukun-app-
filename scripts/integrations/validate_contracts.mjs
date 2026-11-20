#!/usr/bin/env node
// Contract tests: every fixture must satisfy its JSON Schema and every
// "bad" case must be rejected. Run: cd scripts/integrations && npm i && npm run validate
import { readFileSync, readdirSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020 from "ajv/dist/2020.js";
import addFormats from "ajv-formats";

const root = join(dirname(fileURLToPath(import.meta.url)), "../../docs/integrations");
const load = (p) => JSON.parse(readFileSync(join(root, p), "utf8"));
const ajv = new Ajv2020({ allErrors: true, strict: true, strictRequired: false });
addFormats(ajv);

const schemas = {};
for (const f of readdirSync(join(root, "schemas"))) {
  schemas[f.split(".")[0]] = ajv.compile(load(`schemas/${f}`));
}

let failures = 0;
const check = (name, ok) => {
  console.log(`${ok ? "ok  " : "FAIL"} ${name}`);
  if (!ok) failures += 1;
};
const valid = (schema, doc, name) => {
  const ok = schemas[schema](doc);
  check(name, ok);
  if (!ok) console.log(JSON.stringify(schemas[schema].errors, null, 2));
};
const invalid = (schema, doc, name) => check(`rejects: ${name}`, !schemas[schema](doc));

for (const f of ["prescription_issued", "prescription_updated", "prescription_cancelled"]) {
  valid("prescription_event", load(`fixtures/${f}.json`), `fixture ${f}`);
}
valid("progress_event", load("fixtures/progress_event.json"), "fixture progress_event");
valid("progress_summary", load("fixtures/progress_summary.json"), "fixture progress_summary");
valid("template_catalog", load("fixtures/template_catalog.sample.json"), "fixture template_catalog.sample");

const issued = load("fixtures/prescription_issued.json");
const clone = () => structuredClone(issued);
let bad;
bad = clone(); bad.items[0].frequency = undefined; invalid("prescription_event", bad, "item without frequency");
bad = clone(); delete bad.items[0].reminder_times; invalid("prescription_event", bad, "item without reminder_times");
bad = clone(); bad.items = []; invalid("prescription_event", bad, "issued event with no items");
bad = clone(); bad.prescription.staff_only_note = "x"; invalid("prescription_event", bad, "staff-only note field");
bad = clone(); bad.prescription.version = 0; invalid("prescription_event", bad, "version 0");
bad = clone(); bad.patient.password = "secret"; invalid("prescription_event", bad, "a password field");
bad = clone(); bad.items[0].reminder_times = ["7am"]; invalid("prescription_event", bad, "bad time format");
bad = clone(); bad.items[0].count = 0; invalid("prescription_event", bad, "count 0");
bad = clone(); bad.event_type = "prescription.draft"; invalid("prescription_event", bad, "draft events");
bad = clone(); delete bad.prescription.start_date; invalid("prescription_event", bad, "issued without start_date");

const catalog = load("fixtures/template_catalog.sample.json");
check("catalog has the official templates", catalog.templates.length === catalog.total_templates && catalog.total_templates >= 51);
check("template ids are unique", new Set(catalog.templates.map((t) => t.template_id)).size === catalog.templates.length);
check("every template carries a revision hash", catalog.templates.every((t) => /^sha256:[0-9a-f]{64}$/.test(t.template_revision)));
check("placeholders declared as parameters",
  catalog.templates.every((t) => ["{বার}", "{দিন}", "{মিনিট}"].every((p) =>
    t.instruction.includes(p) === t.parameters.some((q) => q.placeholder === p))));

if (failures) { console.error(`${failures} contract check(s) failed`); process.exit(1); }
console.log("all contract checks passed");
