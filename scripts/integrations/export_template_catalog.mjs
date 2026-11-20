#!/usr/bin/env node
// Writes the official template catalog (what GET /templates serves) to a JSON
// file by calling integration_export_template_catalog through psql.
//
//   PGHOST=... PGPORT=... PGUSER=... PGDATABASE=... node export_template_catalog.mjs out.json [--stable]
//
// --stable blanks the volatile timestamps so the file is byte-for-byte
// reproducible (used for the checked-in sample). Never point this at a
// database whose catalog you did not intend to publish.
import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";

const [out, ...flags] = process.argv.slice(2);
if (!out) {
  console.error("usage: export_template_catalog.mjs <out.json> [--stable]");
  process.exit(2);
}
const sql = "select public.integration_export_template_catalog(null, null, 500)";
const raw = execFileSync("psql", ["-X", "-At", "-c", sql], { encoding: "utf8" }).trim();
const catalog = JSON.parse(raw);

if (flags.includes("--stable")) {
  const fixed = "2026-01-01T00:00:00.000000Z";
  catalog.generated_at = fixed;
  catalog.catalog_last_updated_at = fixed;
  for (const t of catalog.templates) t.updated_at = fixed;
}

// Stable key order so diffs only show real changes.
const sortKeys = (v) =>
  Array.isArray(v) ? v.map(sortKeys)
  : v && typeof v === "object"
    ? Object.fromEntries(Object.keys(v).sort().map((k) => [k, sortKeys(v[k])]))
    : v;

writeFileSync(out, JSON.stringify(sortKeys(catalog), null, 2) + "\n");
console.log(`wrote ${catalog.templates.length} templates, catalog_version ${catalog.catalog_version}`);
