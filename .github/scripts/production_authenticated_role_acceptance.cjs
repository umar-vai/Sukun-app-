#!/usr/bin/env node
'use strict';

// MANUAL Production-only acceptance using existing, explicitly approved
// non-real test accounts. Read-only Data API calls from the REAL Pages origin.
// No service-role key, patient names, passwords/JWTs or response bodies in logs.
const assert = require('node:assert/strict');
const { chromium } = require('playwright-core');

const origin = 'https://app.sukunlife.com';
const project = 'https://vydfafumxptanpkmtrpr.supabase.co';
const publishable = 'sb_publishable_bRXqmJeOzc3Dq8BTzyqRKg_gzpAeCPz';
const expectedSha = process.env.SUKUN_EXPECTED_MAIN_SHA;
const accounts = [
  { role: 'member', email: process.env.SUKUN_PRODUCTION_ROLE_MEMBER_EMAIL,
    password: process.env.SUKUN_PRODUCTION_ROLE_MEMBER_PASSWORD },
  { role: 'patient', email: process.env.SUKUN_PRODUCTION_ROLE_PATIENT_EMAIL,
    password: process.env.SUKUN_PRODUCTION_ROLE_PATIENT_PASSWORD },
  { role: 'super_admin', email: process.env.SUKUN_PRODUCTION_ROLE_ADMIN_EMAIL,
    password: process.env.SUKUN_PRODUCTION_ROLE_ADMIN_PASSWORD },
];
let stage = 'preconditions';
function checkpoint(label) {
  stage = label; // Trusted fixed labels; never print account, URL, ID or token.
  console.log('CHECK: ' + label);
}

async function login(account) {
  const res = await fetch(project + '/auth/v1/token?grant_type=password', {
    method: 'POST',
    headers: { apikey: publishable, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: account.email, password: account.password }),
    signal: AbortSignal.timeout(20000),
    redirect: 'error',
  });
  if (res.status !== 200) throw new Error('Dedicated role sign-in failed');
  const data = await res.json();
  if (!data.access_token || !data.user?.id || data.user.is_anonymous) {
    throw new Error('An authenticated non-anonymous test identity is required');
  }
  return { token: data.access_token, uid: data.user.id };
}

async function testRole(browser, account) {
  checkpoint(account.role + ' approved account sign-in');
  const session = await login(account);
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();
  let jsErrors = 0;
  page.on('pageerror', () => { jsErrors += 1; });
  try {
    checkpoint(account.role + ' browser startup');
    const home = await page.goto(origin + '/', {
      waitUntil: 'domcontentloaded', timeout: 60000,
    });
    assert.ok(home?.ok(), 'Production Flutter Web home cannot load');
    checkpoint(account.role + ' authenticated Production browser CORS/RLS');
    const state = await page.evaluate(async ({ project, publishable, token, uid }) => {
      const headers = {
        apikey: publishable,
        authorization: 'Bearer ' + token,
        accept: 'application/json',
      };
      async function read(table, columns, filter = '') {
        const url = project + '/rest/v1/' + table +
          '?select=' + encodeURIComponent(columns) + '&limit=50' + filter;
        const response = await fetch(url, {
          method: 'GET', headers, cache: 'no-store', redirect: 'error',
        });
        if (response.status !== 200) throw new Error('Auth Data API read denied');
        const rows = await response.json();
        if (!Array.isArray(rows)) throw new Error('Unexpected Data API result');
        return rows;
      }
      const [roles, patients, prescriptions, carePlans, actions, publicItems] =
        await Promise.all([
          read('user_roles', 'role,user_id'),
          read('patients', 'id,user_id'),
          read('prescriptions', 'id,patient_id'),
          read('care_plans', 'id,patient_id'),
          read('plan_actions', 'id,care_plan_id'),
          read('content_items', 'id', '&status=eq.published&visibility=eq.public'),
        ]);
      const ownedPatientIds = new Set(patients.filter(p => p.user_id === uid)
        .map(p => p.id));
      const visiblePlanIds = new Set(carePlans.map(p => p.id));
      return {
        ownRole: roles.some(r => r.user_id === uid),
        ownMemberRole: roles.some(r => r.user_id === uid && r.role === 'member'),
        ownPatientRole: roles.some(r => r.user_id === uid && r.role === 'patient'),
        ownAdminRole: roles.some(r => r.user_id === uid && r.role === 'super_admin'),
        foreignRoles: roles.filter(r => r.user_id !== uid).length,
        patientCount: patients.length,
        foreignPatients: patients.filter(p => p.user_id !== uid).length,
        prescriptionCount: prescriptions.length,
        foreignPrescriptions: prescriptions.filter(p =>
          !ownedPatientIds.has(p.patient_id)).length,
        carePlanCount: carePlans.length,
        foreignCarePlans: carePlans.filter(p =>
          !ownedPatientIds.has(p.patient_id)).length,
        actionCount: actions.length,
        actionsWithoutVisiblePlan: actions.filter(a =>
          !visiblePlanIds.has(a.care_plan_id)).length,
        publicItemsAvailable: publicItems.length > 0,
      };
    }, { project, publishable, token: session.token, uid: session.uid });

    assert.ok(state.ownRole && state.publicItemsAvailable,
      'Own role or public CMS access missing');
    if (account.role === 'member') {
      assert.ok(state.ownMemberRole, 'Test Member role mismatch');
      assert.equal(state.foreignRoles, 0);
      for (const key of ['patientCount','prescriptionCount','carePlanCount',
        'actionCount']) assert.equal(state[key], 0, 'Member saw private clinical rows');
    } else if (account.role === 'patient') {
      assert.ok(state.ownPatientRole, 'Test Patient role mismatch');
      assert.equal(state.foreignRoles, 0);
      assert.equal(state.patientCount, 1, 'Patient must see one own record');
      assert.equal(state.foreignPatients, 0);
      assert.equal(state.foreignPrescriptions, 0);
      assert.equal(state.foreignCarePlans, 0);
      assert.equal(state.actionsWithoutVisiblePlan, 0);
    } else {
      assert.ok(state.ownAdminRole, 'Test Super Admin role mismatch');
      assert.ok(state.patientCount > 0, 'Admin cannot see existing test Patients');
    }
    assert.equal(jsErrors, 0, 'Production browser emitted a runtime error');
    console.log('PASS: ' + account.role +
      ' verified browser-origin Production JWT/CORS, public CMS and clinical RLS');
  } finally {
    await context.close(); // No persistent browser storage or credentials.
  }
}

async function main() {
  assert.match(expectedSha || '', /^[a-f0-9]{40}$/,
    'Trusted main SHA is required');
  for (const account of accounts) {
    assert.ok(account.email && account.password,
      'Approved Production test-account GitHub secrets are missing');
  }
  checkpoint('live Pages production SHA');
  const response = await fetch(origin + '/preview-build.json', {
    redirect: 'error', signal: AbortSignal.timeout(20000),
    headers: { 'Cache-Control': 'no-cache' },
  });
  assert.equal(response.status, 200);
  const manifest = await response.json();
  assert.equal(manifest.commit, expectedSha, 'Deployed Pages commit not current');
  assert.equal(manifest.backend_mode, 'production',
    'Refusing non-Production Pages mode');

  const browser = await chromium.launch({
    channel: 'chrome', headless: true, args: ['--no-sandbox'],
  });
  try {
    for (const account of accounts) await testRole(browser, account);
  } finally {
    await browser.close();
  }
  console.log('PASS: authorized Production Member, Patient and Super Admin browser API/RLS');
}

main().catch(() => {
  console.error('FAIL: controlled Production role acceptance at ' + stage);
  process.exitCode = 1;
});
