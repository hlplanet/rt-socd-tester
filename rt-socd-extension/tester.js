'use strict';

// Rapid Trigger & SOCD Tester (browser extension). Uses only web APIs: no permissions, no data leaves the page.

const SITE_URL = 'https://www.hlplanet.com/online-keyboard-tester-tool/';
const HANDOVER_MS = 6; // SOCD: a swap between the two keys this fast is done by the keyboard, not a finger
const SOCD_WINDOW_MS = 3000; // history shown on the SOCD timeline
const PAIRS = {
    ad: ['KeyA', 'KeyD'],
    ws: ['KeyW', 'KeyS'],
    arrows: ['ArrowLeft', 'ArrowRight']
};
const FALLBACK_LABELS = { ArrowLeft: '←', ArrowRight: '→', ArrowUp: '↑', ArrowDown: '↓', Space: 'Space' };

const $ = (sel) => document.querySelector(sel);
const params = new URLSearchParams(location.search);
const isTab = params.has('tab');
const isWindowsApp = params.get('app') === 'windows'; // the same page runs inside the Windows app
document.documentElement.classList.toggle('full-tab', isTab);

// Links back to the website, tagged so visits from the extension / app show up in analytics
const utm = isWindowsApp
    ? '?utm_source=rt-socd-windows&utm_medium=app&utm_campaign='
    : '?utm_source=rt-socd-extension&utm_medium=extension&utm_campaign=';
document.querySelectorAll('[data-site]').forEach((a) => {
    a.href = SITE_URL + utm + a.dataset.site;
});

const store = {
    get(key) {
        try { return localStorage.getItem(key); } catch (err) { return null; }
    },
    set(key, value) {
        try { localStorage.setItem(key, value); } catch (err) { /* storage unavailable */ }
    }
};

// ---- Key labels (follows the user's layout, e.g. AZERTY, where supported) ----

let layoutMap = null;

function label(code) {
    if (!code) return 'Key';
    const mapped = layoutMap ? layoutMap.get(code) : null;
    if (mapped && mapped.length === 1) return mapped.toUpperCase();
    if (FALLBACK_LABELS[code]) return FALLBACK_LABELS[code];
    if (code.startsWith('Key')) return code.slice(3);
    if (code.startsWith('Digit')) return code.slice(5);
    return code;
}

if (navigator.keyboard && navigator.keyboard.getLayoutMap) {
    navigator.keyboard.getLayoutMap().then((map) => {
        layoutMap = map;
        showSocd();
        drawSocd();
        drawTap();
    }).catch(() => {});
}

// ---- Timeline drawing ----

const FONT = getComputedStyle(document.body).fontFamily;

// One lane per key with a bar for every press. Times are event timestamps (same clock as performance.now).
function drawLanes(canvas, lanes, t0, span, extra) {
    const w = canvas.clientWidth;
    const h = canvas.clientHeight;
    if (!w) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const pw = Math.round(w * dpr);
    const ph = Math.round(h * dpr);
    if (canvas.width !== pw || canvas.height !== ph) {
        canvas.width = pw;
        canvas.height = ph;
    }
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, w, h);
    const left = 44;
    const right = w - 8;
    const pad = 5;
    const laneH = (h - pad * 2) / lanes.length;
    const now = performance.now();
    const x = (t) => left + Math.max(0, Math.min(1, (t - t0) / span)) * (right - left);

    if (extra.seconds) {
        ctx.fillStyle = 'rgba(255, 255, 255, 0.08)';
        for (let s = 1; s < span / 1000; s++) ctx.fillRect(x(t0 + s * 1000), pad, 1, h - pad * 2);
    }
    (extra.overlaps || []).forEach(([a, b]) => {
        ctx.fillStyle = 'rgba(246, 173, 85, 0.3)';
        ctx.fillRect(x(a), pad, Math.max(2, x(b) - x(a)), h - pad * 2);
    });
    lanes.forEach((lane, i) => {
        const y = pad + i * laneH;
        ctx.fillStyle = 'rgba(255, 255, 255, 0.04)';
        ctx.fillRect(left, y + 2, right - left, laneH - 4);
        ctx.fillStyle = '#8892b0';
        ctx.font = '700 12px ' + FONT;
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.fillText(lane.label, left / 2, y + laneH / 2);
        ctx.fillStyle = lane.color;
        lane.spans.forEach(([a, b]) => {
            const end = b === null ? now : b;
            if (end < t0) return;
            ctx.fillRect(x(a), y + 6, Math.max(2, x(end) - x(a)), laneH - 12);
        });
    });
    (extra.markers || []).forEach((t) => {
        if (t < t0) return;
        ctx.fillStyle = '#ffe066';
        ctx.fillRect(x(t) - 1, pad, 2, h - pad * 2);
    });
    if (extra.hint) {
        ctx.fillStyle = 'rgba(255, 255, 255, 0.4)';
        ctx.font = '600 12px ' + FONT;
        ctx.fillText(extra.hint, left + (right - left) / 2, h / 2);
    }
}

let raf = null;

function animate() {
    raf = null;
    const now = performance.now();
    let again = false;
    if (tap.phase === 'running') {
        drawTap();
        const left = Math.max(0, (tap.t0 + tap.duration - now) / 1000);
        $('#tap-live').textContent = tap.spans.length + ' taps · ' + left.toFixed(1) + ' s left';
        again = true;
    }
    if (socdActive(now)) {
        drawSocd();
        again = true;
    }
    if (again) raf = requestAnimationFrame(animate);
}

function kick() {
    if (!raf) raf = requestAnimationFrame(animate);
}

const fmtMs = (v) => (v === null ? '--' : (v >= 10 ? Math.round(v) : v.toFixed(1)) + ' ms');

// ---- Rapid trigger tap test ----

const tap = { phase: 'idle', code: null, t0: 0, duration: 5000, spans: [], timer: null };
const tapStat = {};
document.querySelectorAll('[data-tap]').forEach((el) => { tapStat[el.dataset.tap] = el; });

function bestKey() {
    return 'best-taps-' + tap.duration;
}

function showBest() {
    const best = parseFloat(store.get(bestKey()));
    $('#tap-live').textContent = 'Best: ' + (best ? best.toFixed(1) + ' taps/sec' : '--');
}

function drawTap() {
    const hints = { idle: 'Press Start, then tap one key', armed: 'Tap any key to begin' };
    drawLanes($('#tap-canvas'), [{ label: tap.code ? label(tap.code) : 'Key', color: '#00ffaa', spans: tap.spans }],
        tap.t0, tap.duration, { seconds: true, hint: hints[tap.phase] || '' });
}

function tapOnDown(code, t) {
    if (tap.phase === 'armed') {
        tap.phase = 'running';
        tap.code = code;
        tap.t0 = t;
        tap.timer = setTimeout(finishTap, tap.duration);
    }
    if (tap.phase !== 'running' || code !== tap.code) return;
    if (t < tap.t0 + tap.duration) tap.spans.push([t, null]);
    kick();
}

function tapOnUp(code, t) {
    if (code !== tap.code) return;
    const last = tap.spans[tap.spans.length - 1];
    if (last && last[1] === null) last[1] = t;
    if (tap.phase === 'done') drawTap();
}

function tapResults() {
    const s = tap.spans;
    const intervals = [];
    const gaps = [];
    const holds = [];
    s.forEach(([down, up], i) => {
        if (up !== null) holds.push(up - down);
        if (i === 0) return;
        intervals.push(down - s[i - 1][0]);
        if (s[i - 1][1] !== null) gaps.push(down - s[i - 1][1]);
    });
    const avg = (a) => (a.length ? a.reduce((p, v) => p + v, 0) / a.length : null);
    const min = (a) => (a.length ? Math.min(...a) : null);
    return { taps: s.length, rate: s.length / (tap.duration / 1000), fastest: min(intervals), hold: avg(holds), gap: min(gaps) };
}

function showTapResults(r) {
    tapStat.taps.textContent = r ? String(r.taps) : '--';
    tapStat.rate.textContent = r ? r.rate.toFixed(1) : '--';
    tapStat.peak.textContent = r && r.fastest ? (1000 / r.fastest).toFixed(1) : '--';
    tapStat.hold.textContent = r ? fmtMs(r.hold) : '--';
    tapStat.gap.textContent = r ? fmtMs(r.gap) : '--';
}

function finishTap() {
    clearTimeout(tap.timer);
    if (tap.phase !== 'running') return;
    tap.phase = 'done';
    const r = tapResults();
    const best = Math.max(parseFloat(store.get(bestKey())) || 0, r.rate);
    store.set(bestKey(), String(best));
    showTapResults(r);
    $('#tap-live').textContent = 'Done: ' + r.taps + ' taps · best ' + best.toFixed(1) + ' taps/sec';
    $('#tap-start').textContent = 'Start again';
    drawTap();
}

function cancelTap(message) {
    clearTimeout(tap.timer);
    tap.phase = 'idle';
    tap.code = null;
    tap.spans = [];
    $('#tap-start').textContent = 'Start tap test';
    if (message) $('#tap-live').textContent = message;
    else showBest();
    showTapResults(null);
    drawTap();
}

$('#tap-start').addEventListener('click', (e) => {
    e.currentTarget.blur(); // so Space/Enter taps don't re-click the button
    if (tap.phase === 'armed' || tap.phase === 'running') {
        cancelTap('Cancelled.');
        return;
    }
    tap.phase = 'armed';
    tap.code = null;
    tap.spans = [];
    $('#tap-start').textContent = 'Cancel';
    $('#tap-live').textContent = 'Tap any key to begin…';
    showTapResults(null);
    drawTap();
});

$('#tap-duration').addEventListener('change', (e) => {
    tap.duration = parseInt(e.target.value, 10);
    e.target.blur();
    cancelTap();
});

// ---- SOCD / Snap Tap test ----
// SOCD keyboards swap the two keys within a millisecond or two: one is released as the other goes down.
// A person can't do that, so near-instant swaps mean SOCD, real overlaps mean no SOCD.

let pair = PAIRS.ad;
const socd = {};

function resetSocd() {
    Object.assign(socd, {
        spans: { [pair[0]]: [], [pair[1]]: [] },
        down: { [pair[0]]: null, [pair[1]]: null },
        lastUp: { [pair[0]]: -Infinity, [pair[1]]: -Infinity },
        overlaps: 0,
        swaps: 0,
        longest: 0,
        quickest: Infinity,
        markers: [],
        last: -Infinity
    });
    showSocd();
    drawSocd();
}

function socdOnDown(code, t) {
    if (!pair.includes(code)) return;
    const other = code === pair[0] ? pair[1] : pair[0];
    socd.down[code] = t;
    socd.spans[code].push([t, null]);
    // The other key was released a moment ago: the keyboard swapped them
    if (socd.down[other] === null && t - socd.lastUp[other] <= HANDOVER_MS) addSwap(t, t - socd.lastUp[other]);
    touchSocd(t);
}

function socdOnUp(code, t, quiet) {
    if (!pair.includes(code)) return;
    const other = code === pair[0] ? pair[1] : pair[0];
    const spans = socd.spans[code];
    const last = spans[spans.length - 1];
    if (last && last[1] === null) last[1] = t;
    if (!quiet && socd.down[other] !== null) {
        // Both keys were down: briefly means a keyboard swap, longer means a real overlap
        const together = t - Math.max(socd.down[other], socd.down[code] === null ? t : socd.down[code]);
        if (together > HANDOVER_MS) {
            socd.overlaps++;
            socd.longest = Math.max(socd.longest, together);
        } else {
            addSwap(t, together);
        }
    }
    socd.down[code] = null;
    socd.lastUp[code] = quiet ? -Infinity : t;
    touchSocd(t);
}

function addSwap(t, gap) {
    socd.swaps++;
    socd.quickest = Math.min(socd.quickest, Math.max(0, gap));
    socd.markers.push(t);
}

function touchSocd(t) {
    socd.last = t;
    pair.forEach((k) => {
        socd.spans[k] = socd.spans[k].filter(([, b]) => b === null || b > t - 6000);
    });
    socd.markers = socd.markers.filter((m) => m > t - 6000);
    showSocd();
    kick();
}

function showSocd() {
    const a = label(pair[0]);
    const d = label(pair[1]);
    const o = socd.overlaps;
    const s = socd.swaps;
    let state = '';
    let text = 'Hold ' + a + ', then press and release ' + d + ' while still holding ' + a + '. Repeat a few times.';
    if (o === 0 && s >= 2) {
        state = 'on';
        text = 'SOCD / Snap Tap is ON: when both keys are held, only the last one pressed counts.';
    } else if (o === 0 && s === 1) {
        text = 'Keep going, repeat it a few more times.';
    } else if (o > 0 && s === 0) {
        state = 'off';
        text = 'SOCD is OFF: both keys register at the same time (up to ' + Math.round(socd.longest) + ' ms together).';
    } else if (o > 0) {
        state = 'mixed';
        text = 'Mixed results. Keep ' + a + ' fully held while you press ' + d + ', or clear and try again.';
    }
    const verdict = $('#socd-verdict');
    verdict.dataset.state = state;
    verdict.textContent = text;
    $('#socd-counts').textContent = 'Overlaps: ' + o + ' · Instant swaps: ' + s + (s ? ' (fastest ' + socd.quickest.toFixed(1) + ' ms)' : '');
}

function socdActive(now) {
    return socd.down[pair[0]] !== null || socd.down[pair[1]] !== null || now < socd.last + 600;
}

function overlapsOf(aSpans, bSpans, now) {
    const out = [];
    aSpans.forEach(([a1, a2]) => {
        bSpans.forEach(([b1, b2]) => {
            const s = Math.max(a1, b1);
            const e = Math.min(a2 === null ? now : a2, b2 === null ? now : b2);
            if (e - s > HANDOVER_MS) out.push([s, e]);
        });
    });
    return out;
}

function drawSocd() {
    const now = performance.now();
    const anyDown = socd.down[pair[0]] !== null || socd.down[pair[1]] !== null;
    // Freeze shortly after the last event so the result stays on screen
    const end = anyDown || socd.last === -Infinity ? now : Math.min(now, socd.last + 600);
    drawLanes($('#socd-canvas'), [
        { label: label(pair[0]), color: '#00ffaa', spans: socd.spans[pair[0]] },
        { label: label(pair[1]), color: '#00c4ff', spans: socd.spans[pair[1]] }
    ], end - SOCD_WINDOW_MS, SOCD_WINDOW_MS, {
        overlaps: overlapsOf(socd.spans[pair[0]], socd.spans[pair[1]], now),
        markers: socd.markers,
        hint: socd.last === -Infinity ? 'Hold ' + label(pair[0]) + ' and tap ' + label(pair[1]) : ''
    });
}

$('#socd-pair').addEventListener('change', (e) => {
    pair = PAIRS[e.target.value];
    e.target.blur();
    resetSocd();
});

$('#socd-clear').addEventListener('click', (e) => {
    e.currentTarget.blur();
    resetSocd();
});

// ---- Panels ----

document.querySelectorAll('.tab').forEach((btn) => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab').forEach((b) => {
            b.classList.toggle('active', b === btn);
            b.setAttribute('aria-selected', String(b === btn));
        });
        document.querySelectorAll('.panel').forEach((p) => {
            p.hidden = p.id !== 'panel-' + btn.dataset.panel;
        });
        btn.blur();
        store.set('panel', btn.dataset.panel);
        drawTap();
        drawSocd();
    });
});

// ---- Keys ----

const held = new Set();

function codeOf(e) {
    return e.code || (e.key ? 'Key ' + e.key : 'Unidentified');
}

document.addEventListener('keydown', (e) => {
    if (e.key === 'Tab' || e.key === 'Escape') return; // keep keyboard navigation and closing the popup
    if (e.target.tagName === 'SELECT') return;
    e.preventDefault(); // stop Space, arrows and others from scrolling or clicking
    if (e.repeat) return;
    const code = codeOf(e);
    if (held.has(code)) return;
    held.add(code);
    const t = e.timeStamp || performance.now();
    tapOnDown(code, t);
    socdOnDown(code, t);
});

document.addEventListener('keyup', (e) => {
    const code = codeOf(e);
    if (!held.has(code)) return;
    e.preventDefault();
    held.delete(code);
    const t = e.timeStamp || performance.now();
    tapOnUp(code, t);
    socdOnUp(code, t, false);
});

// Keyups never arrive for keys held while the window loses focus
window.addEventListener('blur', () => {
    const now = performance.now();
    held.forEach((code) => {
        tapOnUp(code, now);
        socdOnUp(code, now, true);
    });
    held.clear();
    if (tap.phase === 'armed' || tap.phase === 'running') cancelTap('Cancelled: the window lost focus.');
});

window.addEventListener('resize', () => {
    drawTap();
    drawSocd();
});

// ---- Start ----

resetSocd();
showBest();
drawTap();
const savedPanel = store.get('panel');
if (savedPanel === 'socd') $('.tab[data-panel="socd"]').click();
