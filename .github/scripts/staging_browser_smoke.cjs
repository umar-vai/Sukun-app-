#!/usr/bin/env node
'use strict';

// Real, credential-free Chromium acceptance against the EXISTING Pages app.
// Never collect screenshots, local storage, JWTs, passwords or response bodies.
const assert = require('node:assert/strict');
const { chromium } = require('playwright-core');

const base = 'https://app.sukunlife.com/';
const stagingHost = 'qacklgqvxvjjzsimjoip.supabase.co';
const productionHost = 'vydfafumxptanpkmtrpr.supabase.co';
const expectedCommit = process.env.SUKUN_EXPECTED_MAIN_SHA || '';

function safeError(label) {
  throw new Error(label); // Never include private URLs, response bodies or IDs.
}

async function checkManifest() {
  assert.match(expectedCommit, /^[a-f0-9]{40}$/, 'Expected trusted main SHA absent');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 25000);
  let response;
  try {
    response = await fetch(new URL('preview-build.json', base), {
      redirect: 'error',
      headers: { 'Cache-Control': 'no-cache' },
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timer);
  }
  if (!response?.ok) safeError('Deployed Pages metadata unavailable');
  const metadata = await response.json();
  assert.equal(metadata.commit, expectedCommit, 'Live Pages is not at trusted main SHA');
  assert.equal(metadata.backend_mode, 'staging', 'Pages is not in approved Staging mode');
  console.log('PASS: deployed main SHA and isolated Staging backend mode');
}

async function waitForFlutter(page) {
  await page.waitForFunction(
    () => {
      const view = document.querySelector('flutter-view');
      return Boolean(view && (view.shadowRoot?.childElementCount ||
        view.childElementCount ||
        document.querySelector('flt-glass-pane, canvas')));
    },
    undefined,
    { timeout: 65000 },
  );
  await page.waitForTimeout(900);
}

async function verifyGuestPage(browser, profile) {
  const context = await browser.newContext({
    viewport: profile.viewport,
    deviceScaleFactor: 1,
    isMobile: profile.mobile,
    hasTouch: profile.mobile,
  });
  const failures = [];
  let productionClinicalCalls = 0;
  // Log only trusted, fixed labels: no page content, query URLs or credentials.
  let stage = 'initializing browser';
  const checkpoint = (name) => {
    stage = name;
    console.log('CHECK: ' + profile.label + ' ' + name);
  };
  const page = await context.newPage();

  // Never log external response bodies or request headers.
  page.on('pageerror', () => failures.push('runtime exception'));
  page.on('request', (request) => {
    try {
      const url = new URL(request.url());
      if (url.hostname === productionHost &&
          (url.pathname.startsWith('/auth/v1/') ||
           url.pathname.startsWith('/rest/v1/') ||
           url.pathname.startsWith('/functions/v1/patient-'))) {
        productionClinicalCalls += 1;
      }
    } catch (_) { /* e.g. data URI */ }
  });

  try {
    checkpoint('home boot');
    const response = await page.goto(base, {
      waitUntil: 'domcontentloaded',
      timeout: 65000,
    });
    if (!response?.ok()) safeError('Flutter home entrypoint not available');
    await waitForFlutter(page);

    // Test the publicly accessible login route without entering any data.
    checkpoint('guest login route');
    await page.goto(base + '#/login', {
      waitUntil: 'domcontentloaded',
      timeout: 65000,
    });
    await waitForFlutter(page);
    await page.waitForFunction(
      () => location.hash.includes('/login'),
      undefined,
      { timeout: 12000 },
    );

    // Public guest media library must render without patient credentials.
    checkpoint('public media library route');
    await page.goto(base + '#/my-media', {
      waitUntil: 'domcontentloaded',
      timeout: 65000,
    });
    await waitForFlutter(page);
    await page.waitForFunction(
      () => location.hash.includes('/my-media'),
      undefined,
      { timeout: 12000 },
    );

    // Phase 5: Guest may inspect all five public challenge stages without
    // gaining access to any account-owned day check-ins.
    checkpoint('public 40-day challenge route');
    await page.goto(base + '#/challenge/40-day', {
      waitUntil: 'domcontentloaded',
      timeout: 65000,
    });
    await waitForFlutter(page);
    await page.waitForFunction(
      () => location.hash.includes('/challenge/40-day'),
      undefined,
      { timeout: 12000 },
    );

    // Guest must not remain on either protected deep link after router settles.
    for (const protectedPath of ['/patient/home', '/admin/dashboard']) {
      checkpoint(protectedPath.startsWith('/patient')
        ? 'patient guest protection' : 'admin guest protection');
      await page.goto(base + '#' + protectedPath, {
        waitUntil: 'domcontentloaded',
        timeout: 65000,
      });
      await waitForFlutter(page);
      await page.waitForFunction(
        (blocked) => !location.hash.startsWith('#' + blocked),
        protectedPath,
        { timeout: 20000 },
      );
    }

    checkpoint('final privacy and runtime checks');
    assert.equal(productionClinicalCalls, 0,
      'Staging browser requested Production clinical/auth APIs');
    assert.equal(failures.length, 0, 'Flutter emitted a browser runtime error');
    console.log('PASS: ' + profile.label + ' actual Chromium startup, media library, login route, protected guest redirects and backend separation');
  } catch (_) {
    // Pinpoint the failed trusted milestone without leaking browser state.
    console.error('FAIL: ' + profile.label + ' ' + stage);
    throw new Error('Browser acceptance failed at a named public checkpoint');
  } finally {
    await context.close();
  }
}

(async () => {
  await checkManifest();
  const browser = await chromium.launch({
    channel: 'chrome',
    headless: true,
    args: ['--no-sandbox'],
  });
  try {
    await verifyGuestPage(browser, {
      label: 'desktop',
      viewport: { width: 1366, height: 768 },
      mobile: false,
    });
    await verifyGuestPage(browser, {
      label: 'mobile',
      viewport: { width: 390, height: 844 },
      mobile: true,
    });
  } finally {
    await browser.close();
  }
  console.log('PASS: credential-free browser smoke completed. Real role login and clinical writes remain separate gates.');
})().catch(() => {
  // Do not expose URLs, stack traces, tokens or DOM containing private content.
  console.error('FAIL: Staging Chromium browser acceptance blocked; inspect trusted source and step outcome');
  process.exitCode = 1;
});
