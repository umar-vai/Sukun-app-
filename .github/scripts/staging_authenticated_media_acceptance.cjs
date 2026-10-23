#!/usr/bin/env node
'use strict';

// Explicit, credentialed STAGING release gate. NOT an automated PR or push job.
// Runs Chrome against the canonical Flutter Pages URL and the dedicated staging
// Supabase project; does NOT log credentials, IDs, external URLs or MP3 bytes.
// Requires separately approved offline distribution rights for tested audio.
const assert = require('node:assert/strict');
const { chromium } = require('playwright-core');
const fs = require('node:fs');

const origin = 'https://umar-vai.github.io/Sukun-app-';
const project = 'https://qacklgqvxvjjzsimjoip.supabase.co';
const publishable = 'sb_publishable_V6ALSIa032kI_Ec2q-gpJg_vgpbtXK0';
const maxBytes = 25 * 1024 * 1024;
const rightsFlag = process.env.SUKUN_APPROVED_MP3_OFFLINE_RIGHTS;
const email = process.env.SUKUN_STAGING_MEDIA_TEST_EMAIL;
const password = process.env.SUKUN_STAGING_MEDIA_TEST_PASSWORD;
const commit = process.env.SUKUN_EXPECTED_MAIN_SHA;
let stage = 'preconditions';
const check = (message) => { stage = message; console.log('CHECK: ' + message); };

async function main() {
  assert.equal(rightsFlag, 'true', 'Explicit offline-media rights gate missing');
  assert.ok(email && password, 'Dedicated staging member fixture unavailable');
  assert.match(commit || '', /^[0-9a-f]{40}$/);
  const crosswalk = JSON.parse(fs.readFileSync(
    'app/assets/data/ruqyahbd_book_audio_crosswalk.json', 'utf8'));
  const approved = new Set(crosswalk.entries
    .filter(x => x.licensing === 'owner_attested_for_sukun_life_app_2026_10_12')
    .map(x => x.media_url));

  check('isolated staging member authentication');
  const response = await fetch(project + '/auth/v1/token?grant_type=password', {
    method: 'POST',
    headers: { apikey: publishable, 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password }),
  });
  if (!response.ok) throw new Error('Dedicated staging account sign-in failed');
  const auth = await response.json();
  assert.ok(auth.access_token && auth.user?.id && !auth.user?.is_anonymous,
    'Dedicated authenticated staging member required');

  check('verify fixture is a dedicated General Member');
  const verifiedRoles = await fetch(
    project + '/rest/v1/user_roles?select=role&user_id=eq.' +
    encodeURIComponent(auth.user.id), {
      headers: { apikey: publishable, Authorization: 'Bearer ' + auth.access_token },
    },
  );
  if (!verifiedRoles.ok) {
    throw new Error('Staging member-role verification unavailable');
  }
  const roles = (await verifiedRoles.json()).map(x => x.role);
  assert.deepEqual(roles, ['member'],
    'Media QA requires only a synthetic General Member, never patient/admin');

  check('published public approved audio selection');
  const records = await fetch(
    project + '/rest/v1/content_items?select=id,media_url,status,visibility,type' +
    '&type=eq.audio&visibility=eq.public&status=eq.published&limit=100',
    { headers: { apikey: publishable, Authorization: 'Bearer ' + auth.access_token } },
  );
  assert.equal(records.status, 200, 'Staging member lacks public resource read');
  const candidates = (await records.json()).filter(x => approved.has(x.media_url));
  assert.ok(candidates.length, 'No published approved public MP3 in staging');
  // Choose the smallest eligible approved resource without copying media
  // bytes. A one-byte Range capability probe prevents oversized quota spends.
  const eligible = [];
  for (const candidate of candidates) {
    const probe = await fetch(candidate.media_url, {
      headers: { Range: 'bytes=0-0' },
      redirect: 'manual',
      signal: AbortSignal.timeout(12000),
    }).catch(() => null);
    if (!probe) continue;
    const contentRange = probe.headers.get('content-range') || '';
    const size = Number(contentRange.split('/').pop());
    await probe.body?.cancel().catch(() => {});
    if (probe.status === 206 && Number.isSafeInteger(size) &&
        size >= 4 && size <= maxBytes) eligible.push({ candidate, size });
  }
  eligible.sort((a, b) => a.size - b.size);
  assert.ok(eligible.length, 'No published approved recording fits the QA size budget');
  // Test ONE smallest vetted asset. The backend also enforces daily quotas.
  const item = eligible[0].candidate;

  check('deployed revision and stage isolation');
  const manifest = await fetch(origin + '/preview-build.json');
  assert.equal(manifest.status, 200);
  const info = await manifest.json();
  assert.equal(info.commit, commit);
  assert.equal(info.backend_mode, 'staging');

  const browser = await chromium.launch({
    channel: 'chrome',
    headless: true,
    args: ['--no-sandbox', '--autoplay-policy=no-user-gesture-required'],
  });
  const context = await browser.newContext();
  const page = await context.newPage();
  const key = 'sukun-media-qa-explicit-staging-only';
  try {
    await page.goto(origin, { waitUntil: 'domcontentloaded', timeout: 60000 });
    check('real Chrome JWT/CORS audio fetch and bounded stream');
    const result = await page.evaluate(async ({ project, publishable, token, id, key, maxBytes }) => {
      const controller = new AbortController();
      const request = await fetch(project + '/functions/v1/approved-audio-download?id=' +
        encodeURIComponent(id), {
        method: 'GET',
        headers: { authorization: 'Bearer ' + token, apikey: publishable },
        signal: controller.signal,
      });
      if (request.status !== 200) throw new Error('Authorized gateway response unavailable');
      if (!request.headers.get('content-type')?.includes('audio/mpeg')) {
        throw new Error('Gateway did not provide an MP3 response');
      }
      const declaredLength = Number(request.headers.get('content-length'));
      if (!Number.isSafeInteger(declaredLength) ||
          declaredLength < 4 || declaredLength > maxBytes) {
        controller.abort();
        throw new Error('Media size exceeds intentionally limited QA budget');
      }
      const bytes = new Uint8Array(await request.arrayBuffer());
      if (bytes.length !== declaredLength) throw new Error('Truncated gateway stream');
      if (!(bytes[0] === 73 && bytes[1] === 68 && bytes[2] === 51) &&
          !(bytes[0] === 255 && (bytes[1] & 224) === 224)) {
        throw new Error('Gateway body does not resemble MP3');
      }
      const openDb = () => new Promise((resolve, reject) => {
        const req = indexedDB.open('sukun-public-offline-v1', 1);
        req.onupgradeneeded = () => req.result.createObjectStore('media');
        req.onerror = () => reject(new Error('IndexedDB failed to open'));
        req.onsuccess = () => resolve(req.result);
      });
      const db = await openDb();
      await new Promise((resolve, reject) => {
        const tx = db.transaction('media', 'readwrite');
        tx.objectStore('media').put(bytes, key);
        tx.oncomplete = resolve;
        tx.onerror = () => reject(new Error('IndexedDB write failed'));
      });
      db.close();
      return { bytes: bytes.length };
    }, { project, publishable, token: auth.access_token, id: item.id, key, maxBytes });
    assert.ok(result.bytes > 3);
    check('airplane-mode IndexedDB reopen and MP3 playback source');
    await context.route('**/*', route => route.abort('internetdisconnected'));
    const offline = await page.evaluate(async key => {
      const db = await new Promise((resolve, reject) => {
        const req = indexedDB.open('sukun-public-offline-v1', 1);
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(new Error('IndexedDB reopen failed'));
      });
      const data = await new Promise((resolve, reject) => {
        const tx = db.transaction('media', 'readonly');
        const req = tx.objectStore('media').get(key);
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(new Error('Offline bytes unreadable'));
      });
      if (!(data instanceof Uint8Array) || data.length < 4) {
        throw new Error('Offline media missing');
      }
      const blobUrl = URL.createObjectURL(new Blob([data], { type: 'audio/mpeg' }));
      const audio = new Audio(blobUrl);
      const played = await new Promise(resolve => {
        let settled = false;
        const finish = ok => {
          if (settled) return;
          settled = true;
          audio.pause();
          resolve(ok);
        };
        audio.muted = true;
        audio.ontimeupdate = () => {
          if (audio.currentTime > 0.05) finish(true);
        };
        audio.onloadedmetadata = () => {
          audio.play().catch(() => finish(false));
        };
        audio.onerror = () => finish(false);
        setTimeout(() => finish(false), 12000);
        audio.load();
      });
      URL.revokeObjectURL(blobUrl);
      const tx = db.transaction('media', 'readwrite');
      await new Promise((resolve, reject) => {
        tx.objectStore('media').delete(key);
        tx.oncomplete = resolve;
        tx.onerror = () => reject(new Error('QA cleanup failed'));
      });
      db.close();
      return { ok: played };
    }, key);
    assert.ok(offline.ok, 'Chrome cannot load the saved offline MP3');
    console.log('PASS: authenticated staging gateway -> Chrome IndexedDB -> no-network MP3 load');
  } finally {
    // No page storage, credentials or downloaded media are retained in CI.
    await context.close();
    await browser.close();
  }
}

main().catch(() => {
  console.error('FAIL: controlled staging audio acceptance at ' + stage);
  process.exitCode = 1;
});
