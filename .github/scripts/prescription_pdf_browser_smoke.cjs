'use strict';

const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const { readFile } = require('node:fs/promises');
const { createServer } = require('node:http');
const path = require('node:path');
const { chromium } = require('playwright-core');

const root = path.resolve(process.argv[2]);
const types = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.wasm': 'application/wasm',
  '.png': 'image/png',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
};

const server = createServer(async (request, response) => {
  try {
    const route = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
    const file = path.resolve(root, route === '/' ? 'index.html' : `.${route}`);
    if (!file.startsWith(root + path.sep)) {
      response.writeHead(403).end();
      return;
    }
    const bytes = await readFile(file);
    response.writeHead(200, {
      'Content-Type': types[path.extname(file)] || 'application/octet-stream',
    }).end(bytes);
  } catch {
    response.writeHead(404).end();
  }
});

async function checkBrowser(browser, baseUrl, viewport) {
  const page = await browser.newPage({ viewport, acceptDownloads: true });
  try {
    await page.goto(baseUrl);
    await page.locator('flt-semantics-placeholder').dispatchEvent('click');
    await page.getByRole('img', { name: 'Prescription page 1 / 1' }).waitFor();

    const downloadEvent = page.waitForEvent('download');
    await page.getByRole('button', { name: 'Download PDF' }).click();
    const download = await downloadEvent;
    assert.equal(download.suggestedFilename(), 'sukun-prescription-v2-approved.pdf');
    const bytes = await readFile(await download.path());
    const pdf = bytes.toString('latin1');
    assert.ok(pdf.startsWith('%PDF-'));
    assert.match(pdf, /\/MediaBox\s*\[\s*0\s+0\s+595\.\d+\s+841\.\d+\s*\]/);

    await page.getByRole('button', { name: 'Print PDF' }).click();
    const printFrame = page.locator('iframe#__net_nfet_printing__');
    const printHash = await printFrame.evaluate(async (frame) => {
      const content = await (await fetch(frame.src)).arrayBuffer();
      const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', content));
      return Array.from(digest, (byte) => byte.toString(16).padStart(2, '0')).join('');
    });
    assert.equal(printHash, createHash('sha256').update(bytes).digest('hex'));
    console.log(`PASS: ${viewport.width}px prescription preview, A4 download and print handoff`);
  } finally {
    await page.close();
  }
}

async function main() {
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  try {
    const browser = await chromium.launch({
      channel: process.env.SUKUN_TEST_CHROME ? undefined : 'chrome',
      executablePath: process.env.SUKUN_TEST_CHROME,
      headless: true,
    });
    try {
      const baseUrl = `http://127.0.0.1:${server.address().port}/`;
      await checkBrowser(browser, baseUrl, { width: 1000, height: 820 });
      await checkBrowser(browser, baseUrl, { width: 390, height: 844 });
    } finally {
      await browser.close();
    }
  } finally {
    server.close();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
