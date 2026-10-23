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
  assert.equal(metadata.backend_mode, 'production', 'Live Web App must use the approved Production backend');
  console.log('PASS: live Pages serves the exact main SHA in approved Production mode');
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
  let stagingBackendCalls = 0;
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
      // Production public reads and auth handshakes are expected. Never
      // attempt private patient/admin APIs from a Guest browser.
      const protectedRest = /^\/rest\/v1\/(?:patients?(?:\/|$)|patient_[\w-]+|care_plans?(?:\/|$)|plan_actions?(?:\/|$)|prescriptions?(?:\/|$)|task_(?:completions?|instances?)|private_[\w-]+)/.test(url.pathname);
      const protectedFunction = /^\/functions\/v1\/(?:patient-|admin-|prescription-|dispatch-care-reminders)/.test(url.pathname);
      if (url.hostname === productionHost &&
          (protectedRest || protectedFunction)) {
        productionClinicalCalls += 1;
      }
      if (url.hostname === stagingHost &&
          /^\/(?:auth|rest|functions)\/v1\//.test(url.pathname)) {
        stagingBackendCalls += 1;
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

    // Library action deep links must remain accessible on cold Guest restores.
    // Unknown, synthetic CMS IDs prevent downloading actual publisher bytes.
    for (const action of ['add', 'download']) {
      checkpoint(action === 'add' ? 'guest playlist deep link' :
        'guest offline download deep link');
      const safeId = '00000000-0000-0000-0000-000000000000';
      const target = base + '#/my-media?' + action + '=' + safeId;
      await page.goto(target, {
        waitUntil: 'domcontentloaded',
        timeout: 65000,
      });
      await waitForFlutter(page);
      await page.waitForFunction(
        (expected) => location.hash.includes('/my-media?' + expected + '='),
        action,
        { timeout: 12000 },
      );
    }

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
      // A same-document page.goto('#/...') only changes the fragment.
      // On Chromium it may emit hashchange without a Flutter/go_router route
      // event, giving a false negative for an otherwise protected cold link.
      // Start from a fresh document to verify real direct-link restoration.
      await page.goto('about:blank', { waitUntil: 'domcontentloaded' });
      const protectedResponse = await page.goto(base + '#' + protectedPath, {
        waitUntil: 'domcontentloaded',
        timeout: 65000,
      });
      if (!protectedResponse?.ok()) {
        safeError('Protected deep link did not serve the web entrypoint');
      }
      await waitForFlutter(page);
      try {
        await page.waitForFunction(
          () => {
            const route = location.hash.split('?')[0].replace(/^#/, '');
            return route === '/' || route === '/login';
          },
          undefined,
          { timeout: 20000 },
        );
      } catch (_) {
        // Non-identifying browser readiness and routing flags only; NEVER
        // print the DOM, page URL, response bodies, tokens or account data.
        const signals = await page.evaluate(() => ({
          protectedHashRemains: /^#\\/(patient|admin)(?:\\/|$)/.test(location.hash),
          flutterViewPresent: Boolean(document.querySelector('flutter-view')),
          hasFlutterCanvas: Boolean(document.querySelector('flt-glass-pane, canvas')),
          bootstrapDownloaded: performance.getEntriesByType('resource')
            .some((resource) => /(?:main\\.dart\\.js|main\\.dart\\.mjs)/.test(resource.name)),
          appStillOnLaunchText: (document.body.innerText || '')
            .includes('Faith. Care. Peace of mind.'),
        }));
        console.error('CHECK: Guest protection diagnostic ' +
          JSON.stringify(signals));
        throw new Error('Protected Guest route did not reach a safe location');
      }
    }

    checkpoint('final privacy and runtime checks');
    assert.equal(productionClinicalCalls, 0,
      'Guest browser requested Production protected clinical/admin API');
    assert.equal(stagingBackendCalls, 0,
      'Production Web App called a Staging backend');
    assert.equal(failures.length, 0, 'Flutter emitted a browser runtime error');
    console.log('PASS: ' + profile.label + ' Production Chromium startup, public routes, guest access control and backend isolation');
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
  console.error('FAIL: Production Chromium browser acceptance blocked; inspect trusted source and step outcome');
  process.exitCode = 1;
});
