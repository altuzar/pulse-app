/* Pulse landing-page micro-interactions */
(() => {
    'use strict';

    /* ---------- Reveal on scroll ---------- */
    const io = new IntersectionObserver((entries) => {
        for (const e of entries) {
            if (e.isIntersecting) {
                e.target.classList.add('in');
                io.unobserve(e.target);
            }
        }
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });

    document.querySelectorAll('.reveal').forEach((el) => io.observe(el));

    /* ---------- Hero ECG: rolling synthetic ping data ---------- */
    const path = document.getElementById('ecg-path');
    const mPing = document.getElementById('m-ping');
    const mJitter = document.getElementById('m-jitter');
    const mDown = document.getElementById('m-down');
    const mUp = document.getElementById('m-up');
    const mLoss = document.getElementById('m-loss');
    const statusMeta = document.getElementById('status-meta');

    if (!path) return;

    const W = 600, H = 100;
    const N = 160;
    const series = [];
    let frame = 0;

    // Seed: realistic-feeling 18-30ms latency with occasional spikes
    function nextSample(prev) {
        const baseline = 22;
        let v = prev + (Math.random() - 0.5) * 4;
        v = Math.max(8, Math.min(120, v));
        // occasional spike
        if (Math.random() < 0.04) v += 25 + Math.random() * 35;
        // gentle pull back toward baseline
        v = v + (baseline - v) * 0.06;
        return v;
    }

    let last = 22;
    for (let i = 0; i < N; i++) {
        last = nextSample(last);
        series.push(last);
    }

    function buildPath() {
        // Map latency series -> SVG path. Higher latency = lower y.
        // y range: 8..120ms -> top..bottom
        const max = 130;
        const min = 0;
        const stepX = W / (N - 1);
        let d = '';
        for (let i = 0; i < N; i++) {
            const x = (i * stepX).toFixed(1);
            const y = (H - ((series[i] - min) / (max - min)) * (H - 8) - 4).toFixed(1);
            d += (i === 0 ? 'M ' : ' L ') + x + ' ' + y;
        }
        return d;
    }

    function fmtMs(v) {
        return Math.round(v) + ' ms';
    }
    function fmtMbps(v) {
        return v.toFixed(1) + ' Mbps';
    }

    function tick() {
        // Shift series, add new sample
        last = nextSample(last);
        series.push(last);
        if (series.length > N) series.shift();
        path.setAttribute('d', buildPath());

        // Update metric chips occasionally (every 6 frames)
        if (frame % 6 === 0) {
            mPing.textContent = fmtMs(last);
            const recent = series.slice(-12);
            const mean = recent.reduce((a, b) => a + b, 0) / recent.length;
            const variance = recent.reduce((a, b) => a + (b - mean) ** 2, 0) / recent.length;
            const jitter = Math.sqrt(variance);
            mJitter.textContent = jitter.toFixed(1) + ' ms';

            // simulated speeds: drift slightly
            const baseDown = 95 + Math.sin(frame / 80) * 8;
            const baseUp = 38 + Math.cos(frame / 60) * 4;
            mDown.textContent = fmtMbps(baseDown);
            mUp.textContent = fmtMbps(baseUp);

            mLoss.textContent = (Math.random() < 0.85 ? 0 : 1) + '%';
        }

        if (frame % 30 === 0 && statusMeta) {
            const now = new Date();
            const t = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
            statusMeta.textContent = 'primary 1.1.1.1 · last sample ' + t;
        }

        frame++;
    }

    // Initial draw
    path.setAttribute('d', buildPath());
    setInterval(tick, 220);
})();
