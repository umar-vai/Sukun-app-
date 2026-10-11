/* Browser autoplay gesture regression for the Web Audio FFT bridge.
 * Node fake DOM verifies browser user activation, not real source CORS.
 */
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');

let trustedGesture = false;
let playAttempts = 0;
class FakeAudioElement {
  constructor() {
    this.paused = true;
    this.readyState = 4;
    this.currentTime = 0;
    this.playbackRate = 1;
  }
  play() {
    playAttempts++;
    if (!trustedGesture) {
      const e = new Error('Playback requires a user tap');
      e.name = 'NotAllowedError';
      return Promise.reject(e);
    }
    this.paused = false;
    return Promise.resolve();
  }
  pause() { this.paused = true; }
  removeAttribute() {}
  load() {}
}
class FakeAudioContext {
  constructor() {
    this.state = 'suspended';
    this.sampleRate = 44100;
    this.destination = {};
  }
  createAnalyser() {
    return {
      fftSize: 2048,
      frequencyBinCount: 1024,
      connect() {},
      getByteFrequencyData(buffer) { buffer.fill(170); },
    };
  }
  createGain() {
    return { gain: { value: 1 }, connect() {} };
  }
  createMediaElementSource() {
    return { connect() {} };
  }
  resume() {
    if (!trustedGesture) {
      const e = new Error('User activation required');
      e.name = 'NotAllowedError';
      return Promise.reject(e);
    }
    this.state = 'running';
    return Promise.resolve();
  }
  close() { this.state = 'closed'; return Promise.resolve(); }
}

(async () => {
  const fakeWindow = { AudioContext: FakeAudioContext };
  const sandbox = {
    window: fakeWindow,
    document: {
      hidden: false,
      createElement(name) {
        assert.equal(name, 'audio');
        return new FakeAudioElement();
      },
    },
    performance: { now: () => 10000 },
    Uint8Array, JSON, Math, Number, Promise,
  };
  vm.runInNewContext(
    fs.readFileSync(path.join(__dirname, 'sukun_audio_spectrum.js'), 'utf8'),
    sandbox,
    { filename: 'sukun_audio_spectrum.js' },
  );

  const bridge = fakeWindow.sukunSpectrum;
  bridge.attach('https://cdn.example.test/sample.mp3');
  // Sampling outside an event must not claim a working spectrum.
  bridge.sync(0, true, 1);
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(JSON.parse(bridge.sample()).status, 'gesture-required');

  // A user tap can unlock the AudioContext *and* analysis media element.
  trustedGesture = true;
  bridge.unlock();
  trustedGesture = false;
  await new Promise((resolve) => setImmediate(resolve));
  bridge.sync(0, true, 1);
  const frame = JSON.parse(bridge.sample());
  assert.equal(frame.status, 'active');
  assert.equal(frame.bands.length, 36);
  assert.ok(frame.bass > 0, 'real FFT bins must be read');
  assert.ok(playAttempts >= 2);
  bridge.sync(0, false, 1);
  assert.equal(JSON.parse(bridge.sample()).status, 'paused');
  bridge.stop();
  assert.equal(JSON.parse(bridge.sample()).status, 'idle');
  console.log('PASS Web Audio user gesture and spectrum transitions');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
