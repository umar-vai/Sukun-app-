/* Sukun Life Web-only sound-frequency bridge.
 * Analyses a SECOND muted-in-graph CORS-enabled stream from the same approved
 * URL. Never reroutes/mutes the just_audio playback element; audio keeps
 * working even if cross-origin FFT analysis fails. No microphone or upload.
 */
(() => {
  'use strict';
  let element = null, context = null, analyser = null, silentGain = null;
  let bins = null, url = null, status = 'idle', lastPlayAttempt = 0;
  let pendingPlay = false;
  const nativeCtor = window.AudioContext || window.webkitAudioContext;
  const empty = () => JSON.stringify({status, bands: [], bass: 0, mid: 0, treble: 0});
  const stop = () => {
    if (element) {
      element.pause();
      element.removeAttribute('src');
      element.load();
      element.onerror = null;
      element = null;
    }
    if (context) {
      void context.close().catch(() => {});
      context = null;
    }
    analyser = null;
    silentGain = null;
    bins = null;
    url = null;
    status = 'idle';
    lastPlayAttempt = 0;
    pendingPlay = false;
  };

  const attach = (candidate) => {
    if (typeof candidate !== 'string' || !candidate.startsWith('https://')) {
      stop();
      status = 'unsupported';
      return;
    }
    if (candidate === url && element) return;
    stop();
    if (!nativeCtor) {
      status = 'unsupported';
      return;
    }
    // Only read bytes directly from the current approved source host.
    url = candidate;
    try {
      element = document.createElement('audio');
      element.crossOrigin = 'anonymous'; // Must precede src!
      element.preload = 'none';
      element.playsInline = true;
      element.onerror = () => {
        status = 'cors-or-network'; // Never affects the audible just_audio.
      };
      element.src = candidate;
      status = 'ready';
    } catch (_) {
      stop();
      status = 'unsupported';
    }
  };

  const initGraph = () => {
    if (!element || context) return;
    context = new nativeCtor({latencyHint: 'interactive'});
    analyser = context.createAnalyser();
    analyser.fftSize = 2048;
    analyser.smoothingTimeConstant = 0.75;
    analyser.minDecibels = -95;
    analyser.maxDecibels = -15;
    bins = new Uint8Array(analyser.frequencyBinCount);
    const src = context.createMediaElementSource(element);
    silentGain = context.createGain();
    silentGain.gain.value = 0; // Never duplicate audible output.
    src.connect(analyser);
    analyser.connect(silentGain);
    silentGain.connect(context.destination);
  };

  // Must be called synchronously inside an actual user click/tap, before
  // awaiting Flutter's playback Future. Browsers may refuse AudioContext.resume
  // or a second media element's play() from the 70 ms sampling timer.
  const unlock = () => {
    if (!element || document.hidden || !nativeCtor ||
        status === 'cors-or-network') return;
    try {
      initGraph();
      if (context.state === 'suspended') {
        void context.resume().catch(() => { status = 'gesture-required'; });
      }
      if (element.paused && !pendingPlay) {
        lastPlayAttempt = performance.now();
        pendingPlay = true;
        Promise.resolve(element.play()).then(() => {
          pendingPlay = false;
          status = 'active';
        }).catch((error) => {
          pendingPlay = false;
          status = error && error.name === 'NotAllowedError'
            ? 'gesture-required' : 'cors-or-network';
        });
      }
    } catch (_) {
      status = 'unsupported';
    }
  };

  const sync = (seconds, playing, rate) => {
    if (!element || status === 'cors-or-network' || status === 'unsupported') return;
    if (!playing || document.hidden) {
      element.pause();
      pendingPlay = false;
      if (status === 'active') status = 'paused';
      return;
    }
    try {
      initGraph();
      const speed = Number.isFinite(rate) && rate > 0 ? rate : 1;
      element.playbackRate = speed;
      if (Number.isFinite(seconds) && seconds >= 0 && element.readyState > 0) {
        if (Math.abs(element.currentTime - seconds) > 0.75) {
          element.currentTime = seconds;
        }
      }
      if (context.state === 'suspended') {
        void context.resume().catch(() => {
          status = 'gesture-required';
        });
      }
      const now = performance.now();
      if (element.paused && !pendingPlay && now - lastPlayAttempt > 1300) {
        lastPlayAttempt = now;
        pendingPlay = true;
        const attempt = element.play();
        if (attempt && typeof attempt.then === 'function') {
          void attempt.then(() => {
            pendingPlay = false;
            status = 'active';
          }).catch((error) => {
            pendingPlay = false;
            status = error && error.name === 'NotAllowedError'
              ? 'gesture-required' : 'cors-or-network';
          });
        } else {
          pendingPlay = false;
          status = 'active';
        }
      } else if (!element.paused && context.state === 'running') {
        status = 'active';
      }
    } catch (_) {
      status = 'unsupported';
    }
  };

  function sample() {
    if (!element || !analyser || !bins || status !== 'active') {
      return empty();
    }
    try {
      analyser.getByteFrequencyData(bins);
      const bands = [];
      const sampleRate = context.sampleRate;
      const binHz = sampleRate / analyser.fftSize;
      // 40Hz .. 8kHz log-spaced bands; actual current playback FFT energy.
      const count = 36;
      for (let i = 0; i < count; i++) {
        const startHz = 40 * Math.pow(200, i / count);
        const endHz = 40 * Math.pow(200, (i + 1) / count);
        const startBin = Math.max(1, Math.floor(startHz / binHz));
        const endBin = Math.min(bins.length - 1, Math.max(startBin, Math.ceil(endHz / binHz)));
        let energy = 0;
        for (let b = startBin; b <= endBin; b++) energy += bins[b];
        const amplitude = energy / (endBin - startBin + 1) / 255;
        bands.push(Math.round(Math.pow(amplitude, 1.25) * 1000) / 1000);
      }
      const mean = (values) => values.reduce((a,b) => a+b,0) / Math.max(1,values.length);
      return JSON.stringify({
        status,
        bands,
        bass: mean(bands.slice(0, 10)),
        mid: mean(bands.slice(10, 25)),
        treble: mean(bands.slice(25))
      });
    } catch (_) {
      status = 'unavailable';
      return empty();
    }
  }

  window.sukunSpectrum = Object.freeze({attach, sync, sample, stop, unlock});
})();
