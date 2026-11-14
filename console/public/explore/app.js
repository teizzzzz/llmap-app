/* LLmap View — landing / explore (canvas) / exploration chain. Data: window.LLV_DATA */
(() => {
  'use strict';
  const D = window.LLV_DATA;
  // 桌面: 縮略図は本地 backend の /thumbs/<写真名>（未指定なら同梱の thumbs/）。
  const TH = window.LLV_THUMBS || 'thumbs/';
  const R = D.records;
  const N = R.length;
  // 桌面の研究台に埋め込まれているか。埋め込みでは研究台が範囲・視図・詳情を受け持ち、
  // ここは「画布」（照片云・色彩・主题・関係画布）に徹する（postMessage で連携）。
  const EMBED = !!window.LLV_EMBED && window.parent !== window;
  const post = (msg) => { if (EMBED) window.parent.postMessage(msg, '*'); };
  const IDX = new Map(R.map((r, i) => [r.rid, i]));
  const $ = (id) => document.getElementById(id);
  const rand = (a, b) => a + Math.random() * (b - a);
  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const store = {
    get(k) { try { return JSON.parse(localStorage.getItem(k)); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, JSON.stringify(v)); } catch (e) { /* private mode */ } },
  };
  function rng(seed) {
    let a = seed >>> 0;
    return () => { a = (a + 0x6d2b79f5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  }
  function shuffle(arr, seed) {
    const r = rng(seed), a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) { const j = Math.floor(r() * (i + 1)); [a[i], a[j]] = [a[j], a[i]]; }
    return a;
  }

  // ================================================================ vocab
  // i18n (strings live in i18n.js)
  const I = window.LLV_I18N;
  let LANG = window.LLV_LANG || store.get('llv-lang') || ((navigator.language || '').toLowerCase().startsWith('ja') ? 'ja' : 'zh');
  if (!I[LANG]) LANG = 'zh';
  const t = (k, v) => {
    let s = I[LANG][k] != null ? I[LANG][k] : I.zh[k] != null ? I.zh[k] : k;
    if (v) for (const x in v) s = s.split('{' + x + '}').join(v[x]);
    return s;
  };
  const tr = t; // alias for scopes where `t` is shadowed by a theme object
  const cnl = (c) => I.cn[LANG][c] || c;
  const vf = (v) => (LANG === 'zh' ? v : (I.values[LANG] && I.values[LANG][v]) || v);

  const CN = D.colorNames;
  const CN_SW = { red: '#f0281e', orange: '#ff8a00', yellow: '#ffd000', green: '#12b54a', blue: '#1f66ff', purple: '#8a3cff', pink: '#ff4fa0', brown: '#a0561f', white: '#ffffff', gray: '#a2a2a2', black: '#111111' };
  const LANG_SW = { ja: '#ff3b30', en: '#0a84ff', zh: '#ffb300', ko: '#a347ff', vi: '#16c25a', ne: '#ff2d8a', th: '#00c2b8', hi: '#ff7a00', ar: '#2f5bff', es: '#e0218a', my: '#9bc400', fr: '#3cc4ff', id: '#00a37a', pl: '#ff5b5b', ru: '#7a5cff', ur: '#3dbb6b', sa: '#c28b00' };
  const langName = (c) => (c === 'none' ? t('lang.none') : I.lang[LANG][c] || (D.langs[c] && D.langs[c].name) || c);
  const langColor = (c) => LANG_SW[c] || '#a2a2a2';

  const DIMS = [
    { key: 'cn', get: (r) => [r.cn], order: CN, fmt: (v) => cnl(v), sw: (v) => CN_SW[v], colors: true },
    { key: 'lang', get: (r) => (r.main.length ? r.main : ['none']), fmt: (v) => langName(v), sw: langColor },
    { key: 'rel', get: (r) => [r.f.rel] },
    { key: 'dis', get: (r) => [r.f.dis] },
    { key: 'car', get: (r) => [r.f.car] },
    { key: 'pos', get: (r) => [r.f.pos] },
    { key: 'tmp', get: (r) => [r.f.tmp] },
    { key: 'q', get: (r) => [r.f.q] },
    { key: 'day', get: (r) => [r.t.slice(5, 10).replace('-', '/')], sortByKey: true, fmt: (v) => v },
  ];
  DIMS.forEach((d) => Object.defineProperty(d, 'label', { get: () => t('dim.' + d.key) }));
  const DIM = Object.fromEntries(DIMS.map((d) => [d.key, d]));
  const RANGES = [{ key: 'cf' }, { key: 'L' }];
  RANGES.forEach((rg) => Object.defineProperties(rg, {
    label: { get: () => t('range.' + rg.key) },
    lo: { get: () => t('range.' + rg.key + '.lo') },
    hi: { get: () => t('range.' + rg.key + '.hi') },
  }));
  const VAL = {};
  for (const d of DIMS) VAL[d.key] = R.map(d.get);
  const fmtVal = (d, v) => (d.fmt ? d.fmt(v) : vf(v));

  // search matches both Chinese and Japanese terms
  const SEARCH = R.map((r) => {
    const langs = [...r.main, ...r.aux].flatMap((c) => [I.lang.zh[c] || '', I.lang.ja[c] || '', (D.langs[c] && D.langs[c].name) || '', c]);
    const cols = [r.cn, ...r.pal.map((q) => q[5])].flatMap((c) => [c, I.cn.zh[c], I.cn.zh[c] + '色', I.cn.ja[c], I.cn.ja[c] + '色']);
    const fv = Object.values(r.f).flatMap((v) => [v, I.values.ja[v] || '']);
    return [r.d, r.id, r.note, r.t, ...fv, ...langs, ...cols].join(' ').toLowerCase();
  });

  // ================================================================ color utils
  function hexToOklab(hex) {
    const n = parseInt(hex.slice(1), 16);
    const c = [(n >> 16) & 255, (n >> 8) & 255, n & 255].map((v) => {
      v /= 255; return v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4;
    });
    const l = Math.cbrt(0.4122214708 * c[0] + 0.5363325363 * c[1] + 0.0514459929 * c[2]);
    const m = Math.cbrt(0.2119034982 * c[0] + 0.6806995451 * c[1] + 0.1073969566 * c[2]);
    const s = Math.cbrt(0.0883024619 * c[0] + 0.2817188376 * c[1] + 0.6299787005 * c[2]);
    return [0.2104542553 * l + 0.793617785 * m - 0.0040720468 * s,
      1.9779984951 * l - 2.428592205 * m + 0.4505937099 * s,
      0.0259040371 * l + 0.7827717662 * m - 0.808675766 * s];
  }
  const labDist = (p, q) => Math.hypot(p[2] - q[2], p[3] - q[3], p[4] - q[4]);
  function pickMatch(r, p) {
    for (const q of r.pal) {
      if (q[1] < p.share) continue;
      if (Math.hypot(q[2] - p.lab[0], q[3] - p.lab[1], q[4] - p.lab[2]) <= p.tol) return true;
    }
    return false;
  }
  const repHex = (r) => r.pal[r.rep][0];
  function sharedColor(a, b) {
    let best = null, bs = Infinity;
    for (const p of R[a].pal) for (const q of R[b].pal) {
      if (p[1] < 0.06 || q[1] < 0.06) continue;
      const chroma = Math.hypot(p[3], p[4]);
      const s = labDist(p, q) - 0.12 * Math.min(p[1], q[1]) - 0.15 * Math.min(chroma, 0.15);
      if (s < bs) { bs = s; best = p[0]; }
    }
    return best || repHex(R[a]);
  }
  function palDist(a, b) {
    let s = 0;
    for (const p of R[a].pal) { let m = 9; for (const q of R[b].pal) m = Math.min(m, labDist(p, q)); s += p[1] * m; }
    return s;
  }
  const palHTML = (r, cls = 'pal') => `<div class="${cls}">${r.pal.map((q) => `<i style="background:${q[0]};flex:${q[1]}"></i>`).join('')}</div>`;

  // ================================================================ relations ("接下来探索什么？")
  const CAP = R.map((r) => r.id.replace(/-[a-z]$/, ''));
  const groupBy = (keys, m = new Map()) => { m.clear(); keys.forEach((k, i) => { if (R[i].gone) return; if (!m.has(k)) m.set(k, []); m.get(k).push(i); }); return m; };
  const capMap = groupBy(CAP);
  const lkOf = (r) => r.main.slice().sort().join('+') + '|' + r.aux.slice().sort().join('+');
  const LK = R.map(lkOf);
  const lkMap = groupBy(LK);
  const TK = R.map((r) => r.f.dis + '|' + r.f.car);
  const tkMap = groupBy(TK);
  const MLAT = 111320, MLON = 111320 * Math.cos((35.7016 * Math.PI) / 180);
  const meters = (a, b) => Math.hypot((R[a].lat - R[b].lat) * MLAT, (R[a].lon - R[b].lon) * MLON);
  const shortDis = (s) => vf(s).replace('话语', '');
  const langCombo = (r) => [...r.main, ...r.aux].map(langName).join(t('langsep')) || t('nolang');

  const ICON = {
    color: '<svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8"/><path d="M12 4a8 8 0 0 0 0 16z" fill="currentColor"/></svg>',
    scene: '<svg viewBox="0 0 24 24"><rect x="3.5" y="5" width="17" height="14" rx="3"/><rect x="7" y="8.5" width="5" height="4" rx="1"/><rect x="13.5" y="11" width="4" height="4.5" rx="1"/></svg>',
    near: '<svg viewBox="0 0 24 24"><path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.3"/></svg>',
    lang: '<svg viewBox="0 0 24 24"><path d="M4 5.5h16v10.5H10l-6 4z"/><path d="M8.5 9.5h7M12 8v5.5"/></svg>',
    type: '<svg viewBox="0 0 24 24"><path d="M3.5 12.5V4h8.5l8.5 8.5-8.5 8.5z"/><circle cx="8" cy="8.5" r="1.4"/></svg>',
    contrast: '<svg viewBox="0 0 24 24"><rect x="3.5" y="3.5" width="11" height="11" rx="2.5"/><rect x="9.5" y="9.5" width="11" height="11" rx="2.5" fill="currentColor"/></svg>',
    theme: '<svg viewBox="0 0 24 24"><rect x="4" y="4" width="7" height="7" rx="2"/><rect x="13" y="4" width="7" height="7" rx="2"/><rect x="4" y="13" width="7" height="7" rx="2"/><rect x="13" y="13" width="7" height="7" rx="2"/></svg>',
  };
  const relName = (k) => t('rn.' + k);

  // relation structure is cached; every text is a function so it follows the UI language
  const relCache = new Map();
  function relations(i) {
    if (relCache.has(i)) return relCache.get(i);
    const r = R[i], out = [];
    out.push({
      key: 'color', title: () => t('r.color.t'), sub: () => t('r.color.s', { n: r.nb.length }), all: r.nb.filter((j) => !R[j].gone),
      tag: (j) => t('r.color.tag', { c: cnl(R[j].cn) }), link: (j) => ({ dot: sharedColor(i, j) }),
    });
    const sib = (capMap.get(CAP[i]) || []).filter((j) => j !== i);
    if (sib.length) out.push({
      key: 'scene', title: () => t('r.scene.t'), sub: () => t('r.scene.s', { n: sib.length }), all: sib,
      tag: () => t('r.scene.tag'), link: () => ({ text: t('r.scene.link') }),
    });
    const near = [];
    for (let j = 0; j < N; j++) if (CAP[j] !== CAP[i] && !R[j].gone && R[j].lat != null) near.push([meters(i, j), j]);
    near.sort((a, b) => a[0] - b[0]);
    const nearSel = near.slice(0, 24);
    const radius = nearSel.length ? Math.max(5, Math.round(nearSel[nearSel.length - 1][0])) : 0;
    if (nearSel.length && r.lat != null) out.push({
      key: 'near', title: () => t('r.near.t'), sub: () => t('r.near.s', { m: radius, n: nearSel.length }), all: nearSel.map((x) => x[1]),
      tag: (j) => t('r.near.tag', { m: Math.round(meters(i, j)) }), link: (j) => ({ text: t('r.near.link', { m: Math.round(meters(i, j)) }) }),
    });
    if (r.main.length) {
      const same = lkMap.get(LK[i]).filter((j) => j !== i);
      if (same.length) out.push({
        key: 'lang', title: () => t('r.lang.t', { x: langCombo(r) }), sub: () => t('r.lang.s', { n: same.length }), all: shuffle(same, i * 31 + 1),
        tag: () => langCombo(r), link: () => ({ text: r.main.map(langName).join('+') }),
      });
    }
    const st = tkMap.get(TK[i]).filter((j) => j !== i);
    if (st.length) out.push({
      key: 'type', title: () => `${shortDis(r.f.dis)} · ${vf(r.f.car)}`, sub: () => t('r.type.s', { n: st.length }), all: shuffle(st, i * 31 + 2),
      tag: () => `${shortDis(r.f.dis)}·${vf(r.f.car)}`, link: () => ({ text: `${shortDis(r.f.dis)}·${vf(r.f.car)}` }),
    });
    if (r.main.length) {
      const L0 = r.main[0], cands = [];
      for (let j = 0; j < N; j++) if (j !== i && !R[j].gone && R[j].main[0] === L0 && R[j].chr) cands.push([palDist(i, j), j]);
      cands.sort((a, b) => b[0] - a[0]);
      if (cands.length) out.push({
        key: 'contrast', title: () => t('r.contrast.t'), sub: () => t('r.contrast.s', { x: langName(L0) }), all: shuffle(cands.slice(0, 60).map((x) => x[1]), i * 31 + 3).slice(0, 24),
        tag: (j) => t('r.contrast.tag', { c: cnl(R[j].cn) }), link: () => ({ text: t('r.contrast.link') }),
      });
    }
    relCache.set(i, out);
    return out;
  }
  const relOf = (i, key) => relations(i).find((x) => x.key === key);

  /** HTML for the A&C-style "what next" block */
  function nextHTML(i, activeKey) {
    const rels = relations(i);
    const card = (rel, big) => {
      const cover = R[rel.all[0]];
      const stack = rel.all.slice(1, 4).map((j) => `<i style="background-image:url('${TH}${R[j].ph}')"></i>`).join('');
      return `<button class="nx${big ? ' big' : ''}${rel.key === activeKey ? ' on' : ''}" data-k="${rel.key}" style="background-image:url('${TH}${cover.ph}')">
        <span class="badge-l">${ICON[rel.key]}${relName(rel.key)}</span>${big ? `<span class="stack">${stack}</span>` : ''}
        <span class="nx-t"><b>${esc(rel.title())}</b><small>${esc(rel.sub())}</small></span></button>`;
    };
    // mixed "more" feed: round-robin across relations
    const seen = new Set([i]), more = [];
    for (let k = 0; more.length < 16 && k < 8; k++) for (const rel of rels) {
      const j = rel.all[k + (rel.key === 'color' ? 0 : 1)];
      if (j != null && !seen.has(j)) { seen.add(j); more.push([j, rel]); }
    }
    return `<h4 class="nx-h">${t('next.h')}</h4>
      <div class="nx-cards">${card(rels[0], true)}<div class="nx-grid">${rels.slice(1).map((r) => card(r)).join('')}</div></div>
      <h4 class="more-h">${t('next.more')}<button data-shuffle aria-label="${t('next.shuffle')}" title="${t('next.shuffle')}"><svg viewBox="0 0 24 24"><path d="M4 12a8 8 0 0 1 14-5.3M20 12a8 8 0 0 1-14 5.3"/><path d="M18 3v4h-4M6 21v-4h4"/></svg></button></h4>
      <div class="masonry">${more.map(([j, rel]) => `<button class="mi" data-j="${j}" data-k="${rel.key}"><img src="${TH}${R[j].ph}" alt="" loading="lazy"><span class="mi-t">${ICON[rel.key]}<span><b>${relName(rel.key)}</b> ${esc(rel.tag(j))}</span></span></button>`).join('')}</div>`;
  }
  function bindNext(root, i, onCard, onMore) {
    root.querySelectorAll('.nx').forEach((b) => (b.onclick = () => onCard(b.dataset.k)));
    root.querySelectorAll('.mi').forEach((b) => (b.onclick = () => onMore(+b.dataset.j, b.dataset.k)));
    const sh = root.querySelector('[data-shuffle]');
    if (sh) sh.onclick = () => {
      // rotate each relation list so the feed changes
      for (const rel of relations(i)) if (rel.all.length > 3) rel.all.push(...rel.all.splice(1, 3));
      onCard(null, true);
    };
  }

  // ================================================================ state
  const S = {
    view: 'landing', mode: 'wall', sort: 'spec', group: 'cn',
    sel: {}, range: {}, pick: null, rel: null, q: '', theme: null,
    selected: null, trail: [], panel: false,
  };
  const active = new Uint8Array(N).fill(1);
  // 研究台の範囲（資料庫の筛选・記録集合・選択）。範囲外は描かない（色彩でも消す）。
  // 探索内の条件（色・言語・関連など）は範囲の内側をさらに絞る（色彩では薄く残す）。
  const base = new Uint8Array(N);
  for (let i = 0; i < N; i++) base[i] = R[i].gone ? 0 : 1;
  // 研究台で手動選択した記録（小さな印を描く）。
  let checked = new Set();

  // ================================================================ filtering
  function relSet() {
    if (!S.rel) return null;
    const rel = relOf(S.rel.i, S.rel.key);
    return new Set([S.rel.i, ...(rel ? rel.all : [])]);
  }
  const qTokens = () => S.q.toLowerCase().split(/\s+/).filter(Boolean);
  function passes(i, except, rs, toks) {
    if (!base[i]) return false;
    for (const k in S.sel) {
      if (k === except) continue;
      const set = S.sel[k];
      if (set.size && !VAL[k][i].some((v) => set.has(v))) return false;
    }
    for (const k in S.range) {
      if (k === except) continue;
      const [lo, hi] = S.range[k];
      if (R[i][k] < lo || R[i][k] > hi) return false;
    }
    if (S.pick && !pickMatch(R[i], S.pick)) return false;
    if (rs && !rs.has(i)) return false;
    if (toks.length) for (const t of toks) if (!SEARCH[i].includes(t)) return false;
    return true;
  }
  function filterCount() {
    return Object.values(S.sel).reduce((s, x) => s + x.size, 0) + Object.keys(S.range).length + (S.pick ? 1 : 0) + (S.rel ? 1 : 0) + (S.q ? 1 : 0);
  }
  function recompute(opts = {}) {
    if (!opts.keepTheme) S.theme = null;
    const rs = relSet(), toks = qTokens();
    let n = 0;
    for (let i = 0; i < N; i++) { active[i] = passes(i, null, rs, toks) ? 1 : 0; n += active[i]; }
    $('count').textContent = n.toLocaleString();
    const fc = filterCount();
    $('filter-badge').hidden = !fc;
    $('filter-badge').textContent = fc;
    if (S.panel) renderCharts(rs, toks);
    renderChips();
    renderHeading(n);
    if (exploreReady) layout(opts.keepCamera);
    writeHash();
    tellState(n);
  }
  // 研究台へ: 表示中の件数と、探索内の条件（研究台の筛选栏に「探索条件」として出す）。
  function conditions() {
    const out = [];
    if (S.q) out.push({ id: 'q', label: `“${S.q}”` });
    for (const [k, set] of Object.entries(S.sel)) for (const v of set) {
      const d = DIM[k];
      out.push({ id: `sel:${k}:${v}`, label: `${d.label}: ${fmtVal(d, v)}`, dot: d.sw ? d.sw(v) : null });
    }
    for (const rg of RANGES) if (S.range[rg.key]) {
      const [lo, hi] = S.range[rg.key];
      out.push({ id: `range:${rg.key}`, label: `${rg.label} ${Math.round(lo * 100)}–${Math.round(hi * 100)}` });
    }
    if (S.pick) out.push({ id: 'pick', label: t('chip.pick'), dot: S.pick.hex });
    if (S.rel) out.push({ id: 'rel', label: `${relName(S.rel.key)} · ${R[S.rel.i].d.slice(-10)}` });
    return out;
  }
  function tellState(n) {
    if (!EMBED) return;
    if (n == null) { n = 0; for (let i = 0; i < N; i++) n += active[i]; }
    let inBase = 0; for (let i = 0; i < N; i++) inBase += base[i];
    const groups = S.mode === 'group' ? groupBlocks.map((g) => ({ v: g.v, label: fmtVal(g.d, g.v), n: g.n, sw: g.d.sw ? g.d.sw(g.v) : null, ph: R[g.rep].ph })) : [];
    post({ type: 'llmap:state', shown: n, inScope: inBase, conds: conditions(), mode: S.mode, group: S.group, sort: S.sort, panel: S.panel,
      groups, focus: focusIdx >= 0 && groupBlocks[focusIdx] ? groupBlocks[focusIdx].v : null });
  }
  function clearCondition(id) {
    if (id === 'q') { S.q = ''; $('search').value = ''; }
    else if (id === 'pick') S.pick = null;
    else if (id === 'rel') S.rel = null;
    else if (id.startsWith('range:')) delete S.range[id.slice(6)];
    else if (id.startsWith('sel:')) {
      const [, k, ...rest] = id.split(':');
      const v = rest.join(':');
      if (S.sel[k]) { S.sel[k].delete(v); if (!S.sel[k].size) delete S.sel[k]; }
    }
  }

  function renderHeading(n) {
    const parts = [];
    for (const [k, set] of Object.entries(S.sel)) for (const v of set) parts.push(fmtVal(DIM[k], v));
    if (S.q) parts.push(`“${S.q}”`);
    if (S.pick) parts.push(t('head.pick'));
    for (const rg of RANGES) if (S.range[rg.key]) parts.push(`${rg.label} ${Math.round(S.range[rg.key][0] * 100)}–${Math.round(S.range[rg.key][1] * 100)}`);
    let title = S.theme ? t(`th.${S.theme.id}.t`) : (parts.length ? parts.join(' · ') : t('head.all'));
    if (S.rel && !S.theme) {
      const rel = relOf(S.rel.i, S.rel.key);
      title = `${R[S.rel.i].d.slice(-10)} · ${rel ? rel.title() : ''}` + (parts.length ? ' · ' + parts.join(' · ') : '');
    }
    let scenes = new Set(), langs = new Set();
    for (let i = 0; i < N; i++) if (active[i]) { scenes.add(CAP[i]); R[i].main.forEach((l) => langs.add(l)); }
    if (EMBED) return;
    $('ctx-t').textContent = title;
    $('ctx-s').innerHTML = t('head.sub', { n: n.toLocaleString(), s: scenes.size, l: langs.size });
  }

  // ================================================================ filter panel
  const allValues = {};
  for (const d of DIMS) {
    const c = new Map();
    VAL[d.key].forEach((vs) => vs.forEach((v) => c.set(v, (c.get(v) || 0) + 1)));
    let vals = [...c.keys()];
    if (d.order) vals = d.order.filter((v) => c.has(v));
    else if (d.sortByKey) vals.sort();
    else vals.sort((a, b) => c.get(b) - c.get(a));
    allValues[d.key] = vals;
  }

  function renderCharts(rs = relSet(), toks = qTokens()) {
    const frag = document.createDocumentFragment();
    for (const d of DIMS) {
      const counts = new Map();
      for (let i = 0; i < N; i++) {
        if (!passes(i, d.key, rs, toks)) continue;
        for (const v of VAL[d.key][i]) counts.set(v, (counts.get(v) || 0) + 1);
      }
      const set = S.sel[d.key] || new Set();
      const box = document.createElement('div');
      box.className = 'chart' + (set.size ? ' has-sel' : '');
      box.innerHTML = `<div class="sec-t"><span>${d.label}</span>${set.size ? `<button class="txt clear">${t('panel.clear')}</button>` : ''}</div>`;
      if (d.colors) {
        const grid = document.createElement('div');
        grid.className = 'colors';
        for (const v of allValues[d.key]) {
          const n = counts.get(v) || 0;
          const b = document.createElement('button');
          b.className = 'cbtn' + (set.has(v) ? ' sel' : '') + (n ? '' : ' zero');
          b.title = `${cnl(v)} · ${n}`;
          b.innerHTML = `<i style="background:${CN_SW[v]}"></i>${n}`;
          b.onclick = (e) => toggleSel(d.key, v, e.shiftKey || e.metaKey || e.ctrlKey);
          grid.appendChild(b);
        }
        box.appendChild(grid);
      } else {
        const max = Math.max(1, ...allValues[d.key].map((v) => counts.get(v) || 0));
        for (const v of allValues[d.key]) {
          const n = counts.get(v) || 0;
          const row = document.createElement('div');
          row.className = 'row' + (set.has(v) ? ' sel' : '') + (n ? '' : ' zero');
          const sw = d.sw ? `<i class="sw" style="background:${d.sw(v)}"></i>` : '';
          row.innerHTML = `<span class="lab" title="${esc(fmtVal(d, v))}">${sw}${esc(fmtVal(d, v))}</span><span class="bar"><i style="width:${(n / max) * 100}%;${d.sw ? 'background:' + d.sw(v) : ''}"></i></span><span class="n">${n}</span>`;
          row.onclick = (e) => toggleSel(d.key, v, e.shiftKey || e.metaKey || e.ctrlKey);
          box.appendChild(row);
        }
      }
      const clr = box.querySelector('.clear');
      if (clr) clr.onclick = () => { delete S.sel[d.key]; recompute(); };
      frag.appendChild(box);
    }
    for (const rg of RANGES) frag.appendChild(histogram(rg, rs, toks));
    $('charts').replaceChildren(frag);
  }

  function toggleSel(key, v, additive) {
    const set = S.sel[key] || (S.sel[key] = new Set());
    if (set.has(v)) set.delete(v);
    else { if (!additive) set.clear(); set.add(v); }
    if (!set.size) delete S.sel[key];
    recompute();
  }

  function histogram(rg, rs, toks) {
    const BINS = 28;
    const all = new Array(BINS).fill(0), cur = new Array(BINS).fill(0);
    for (let i = 0; i < N; i++) {
      if (!base[i]) continue;
      const b = Math.min(BINS - 1, Math.floor(R[i][rg.key] * BINS));
      all[b]++;
      if (passes(i, rg.key, rs, toks)) cur[b]++;
    }
    const max = Math.max(...all);
    const W = 272, H = 48, bw = W / BINS;
    const range = S.range[rg.key];
    const box = document.createElement('div');
    box.className = 'chart hist';
    box.innerHTML = `<div class="sec-t"><span>${rg.label}</span>${range ? `<button class="txt clear">${t('panel.clear')}</button>` : ''}</div>`;
    const ns = 'http://www.w3.org/2000/svg';
    const svg = document.createElementNS(ns, 'svg');
    svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
    svg.setAttribute('preserveAspectRatio', 'none');
    let html = '';
    for (let b = 0; b < BINS; b++) {
      const h0 = Math.max(1, (all[b] / max) * (H - 2)), h1 = (cur[b] / max) * (H - 2);
      const inR = !range || ((b + 0.5) / BINS >= range[0] && (b + 0.5) / BINS <= range[1]);
      html += `<rect x="${b * bw + 1}" y="${H - h0}" width="${bw - 2}" height="${h0}" rx="1.5" fill="#e8e8e8"/>`;
      if (h1) html += `<rect x="${b * bw + 1}" y="${H - h1}" width="${bw - 2}" height="${h1}" rx="1.5" fill="${inR ? '#0f0f0e' : '#c6c6c6'}"/>`;
    }
    svg.innerHTML = html;
    const brush = document.createElementNS(ns, 'rect');
    brush.setAttribute('y', 0); brush.setAttribute('height', H); brush.setAttribute('rx', 4);
    brush.setAttribute('fill', 'rgba(15,15,14,.08)');
    svg.appendChild(brush);
    let x0 = null;
    const fx = (e) => { const b = svg.getBoundingClientRect(); return Math.max(0, Math.min(1, (e.clientX - b.left) / b.width)); };
    svg.onpointerdown = (e) => { x0 = fx(e); svg.setPointerCapture(e.pointerId); };
    svg.onpointermove = (e) => {
      if (x0 == null) return;
      const x1 = fx(e);
      brush.setAttribute('x', Math.min(x0, x1) * W); brush.setAttribute('width', Math.abs(x1 - x0) * W);
    };
    svg.onpointerup = (e) => {
      if (x0 == null) return;
      const x1 = fx(e);
      if (Math.abs(x1 - x0) < 0.02) delete S.range[rg.key];
      else S.range[rg.key] = [Math.min(x0, x1), Math.max(x0, x1)];
      x0 = null; recompute();
    };
    box.appendChild(svg);
    const ax = document.createElement('div');
    ax.className = 'axis'; ax.innerHTML = `<span>${rg.lo}</span><span>${t('panel.drag')}</span><span>${rg.hi}</span>`;
    box.appendChild(ax);
    const clr = box.querySelector('.clear');
    if (clr) clr.onclick = () => { delete S.range[rg.key]; recompute(); };
    return box;
  }

  function setPanel(open) {
    S.panel = open;
    $('panel').hidden = !open;
    document.body.classList.toggle('panel-open', open);
    $('toggle-filter').classList.toggle('on', open);
    if (open) renderCharts();
    if (exploreReady) layout(true);
    tellState();
  }
  $('toggle-filter').onclick = () => setPanel(!S.panel);

  function applyPick() {
    const hex = $('pick-color').value;
    S.pick = { hex, lab: hexToOklab(hex), tol: +$('pick-tol').value, share: +$('pick-share').value };
    recompute();
  }
  $('pick-apply').onclick = applyPick;
  ['pick-color', 'pick-tol', 'pick-share'].forEach((id) => ($(id).oninput = () => { if (S.pick) applyPick(); }));
  $('pick-clear').onclick = () => { S.pick = null; recompute(); };
  $('reset').onclick = () => { clearFilters(); recompute(); };
  function clearFilters() {
    S.sel = {}; S.range = {}; S.pick = null; S.rel = null; S.q = ''; $('search').value = '';
  }

  const X_SVG = '<svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg>';
  function renderChips() {
    const chips = [];
    if (S.q) chips.push({ html: `“${esc(S.q)}”`, off: () => { S.q = ''; $('search').value = ''; } });
    for (const [k, set] of Object.entries(S.sel)) for (const v of set) {
      const d = DIM[k];
      const dot = d.sw ? `<i class="dot" style="background:${d.sw(v)}"></i>` : '';
      chips.push({ html: `${dot}${esc(fmtVal(d, v))}`, off: () => { set.delete(v); if (!set.size) delete S.sel[k]; } });
    }
    for (const rg of RANGES) if (S.range[rg.key]) {
      const [lo, hi] = S.range[rg.key];
      chips.push({ html: `${rg.label} ${Math.round(lo * 100)}–${Math.round(hi * 100)}`, off: () => delete S.range[rg.key] });
    }
    if (S.pick) chips.push({ html: `<i class="dot" style="background:${S.pick.hex}"></i>${t('chip.pick')}`, off: () => (S.pick = null) });
    if (S.rel) chips.push({ html: `${ICON[S.rel.key]}${relName(S.rel.key)}`, off: () => (S.rel = null) });
    $('chips').replaceChildren(...chips.map((c) => {
      const b = document.createElement('button');
      b.className = 'chip';
      b.innerHTML = `${c.html}<span class="x">${X_SVG}</span>`;
      b.onclick = () => { c.off(); recompute(); };
      return b;
    }));
  }

  let qTimer = 0;
  $('search').addEventListener('input', (e) => {
    clearTimeout(qTimer);
    qTimer = setTimeout(() => { S.q = e.target.value.trim(); recompute(); }, 180);
  });
  $('search').addEventListener('keydown', (e) => { if (e.key === 'Escape') { e.target.value = ''; S.q = ''; recompute(); } });

  // ================================================================ explore canvas
  const cv = $('cv');
  const ctx = cv.getContext('2d');
  const exploreEl = $('explore');
  const labelsEl = $('labels');
  let W = 0, H = 0, DPR = 1, exploreReady = false;
  const cam = { x: 0, y: 0, k: 10 }, camFrom = { x: 0, y: 0, k: 10 }, camTo = { x: 0, y: 0, k: 10 };
  let camAnim = -1;
  const GAP = 0.14, RAD = 0.14;

  const mk = () => ({ x: new Float32Array(N), y: new Float32Array(N), a: new Float32Array(N), s: new Float32Array(N).fill(1) });
  const cur = mk(), from = mk(), to = mk();
  const delay = new Float32Array(N);
  let animStart = 0, animating = false, labels = [];
  const DUR = 950, STAGGER = 420;

  const atlas = new Image();
  atlas.src = (window.LLV_ASSET_BASE || '') + D.atlas.file;
  atlas.onload = () => requestDraw();
  const TILE = D.atlas.tile, ACOLS = D.atlas.cols;

  const basemap = new Image();
  if (window.LLMAP_BASEMAP) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1100 350" width="2200" height="700">${window.LLMAP_BASEMAP}</svg>`;
    basemap.src = 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
    basemap.onload = () => requestDraw();
  }
  const MAP_S = 4.2;

  function resize() {
    DPR = window.devicePixelRatio || 1;
    W = exploreEl.clientWidth; H = exploreEl.clientHeight;
    cv.width = Math.round(W * DPR); cv.height = Math.round(H * DPR);
    requestDraw();
  }
  let lastW = 0, lastH = 0;
  new ResizeObserver(() => {
    resize();
    if (exploreReady && (Math.abs(lastW - W) > 40 || Math.abs(lastH - H) > 40)) layout();
    lastW = W; lastH = H;
  }).observe(exploreEl);

  const navH = () => parseInt(getComputedStyle(document.body).getPropertyValue('--nav-h')) || 76;
  function safeRect() {
    const mobile = W < 720;
    // 研究台の操作（上の分組・下の組の帯）に隠れないよう余白を取る。
    if (EMBED) return { l: S.panel && !mobile ? 340 : 24, r: 24, t: 60, b: S.mode === 'group' ? 72 : 32 };
    return {
      l: S.panel && !mobile ? 348 : 28,
      r: !$('detail').hidden && !mobile ? 428 : 28,
      t: navH() + (mobile ? 50 : 84),
      b: 96,
    };
  }

  const sorters = {
    spec: (a, b) => R[a].sp - R[b].sp,
    light: (a, b) => R[b].L - R[a].L || R[a].sp - R[b].sp,
    cf: (a, b) => R[b].cf - R[a].cf,
    time: (a, b) => (R[a].t < R[b].t ? -1 : R[a].t > R[b].t ? 1 : 0),
    lang: (a, b) => {
      const la = R[a].main[0] || 'zz', lb = R[b].main[0] || 'zz';
      return la < lb ? -1 : la > lb ? 1 : R[a].sp - R[b].sp;
    },
  };
  let mapPos = null;
  function computeMapPos() {
    const occ = new Set(), pos = new Array(N);
    const order = [...Array(N).keys()].sort((a, b) => R[a].x - R[b].x || R[a].sp - R[b].sp);
    const spiral = [];
    for (let r = 0; r <= 40; r++) for (let dx = -r; dx <= r; dx++) for (let dy = -r; dy <= r; dy++)
      if (Math.max(Math.abs(dx), Math.abs(dy)) === r) spiral.push([dx, dy, dx * dx + dy * dy]);
    spiral.sort((a, b) => a[2] - b[2]);
    for (const i of order) {
      const cx = Math.round(R[i].x / MAP_S), cy = Math.round(R[i].y / MAP_S);
      for (const [dx, dy] of spiral) {
        const k = (cx + dx) + ',' + (cy + dy);
        if (!occ.has(k)) { occ.add(k); pos[i] = [cx + dx, cy + dy]; break; }
      }
      if (!pos[i]) pos[i] = [cx, cy];
    }
    return pos;
  }

  const cloudScore = (i) => R[i].cf * 0.7 + (R[i].chr ? 0.3 : 0) + (R[i].pal[R[i].rep][1] || 0) * 0.2;

  // 照片云の分組（全貌 → 分組 → 写真 の 3 段の見方）。focus 中は他の組を薄くする。
  let groupBlocks = [];
  const groupOf = new Int32Array(N).fill(-1);
  let focusIdx = -1;
  function layout(keepCamera) {
    for (let i = 0; i < N; i++) { from.x[i] = cur.x[i]; from.y[i] = cur.y[i]; from.a[i] = cur.a[i]; from.s[i] = cur.s[i]; }
    labels = [];
    groupBlocks = []; groupOf.fill(-1); focusIdx = -1;
    const ids = [];
    for (let i = 0; i < N; i++) if (active[i]) ids.push(i);
    const sr = safeRect();
    const aspect = Math.max(0.5, (W - sr.l - sr.r) / Math.max(1, H - sr.t - sr.b));
    const DIM_A = 0.06;
    for (let i = 0; i < N; i++) to.s[i] = 1;
    const hideInactive = () => {
      for (let i = 0; i < N; i++) if (!active[i]) { to.x[i] = from.x[i]; to.y[i] = from.y[i]; to.s[i] = from.s[i]; to.a[i] = 0; delay[i] = 0; }
    };

    if (S.mode === 'wall') {
      ids.sort(sorters[S.sort]);
      const cols = Math.max(3, Math.ceil(Math.sqrt(ids.length * aspect)));
      ids.forEach((i, k) => { to.x[i] = k % cols; to.y[i] = Math.floor(k / cols); to.a[i] = 1; delay[i] = (k / Math.max(1, ids.length)) * STAGGER; });
      hideInactive();
    } else if (S.mode === 'group') {
      const d = DIM[S.group];
      const groups = new Map();
      for (const i of ids) {
        const v = VAL[d.key][i][0];
        if (!groups.has(v)) groups.set(v, []);
        groups.get(v).push(i);
      }
      let keys = [...groups.keys()];
      if (d.order) keys = d.order.filter((v) => groups.has(v));
      else keys.sort((a, b) => groups.get(b).length - groups.get(a).length);
      // each group is a plain square grid of equal tiles, ordered by colour spectrum
      const multi = keys.length > 1;
      const MINW = multi ? 7 : 0; // leave room for the label above small groups
      const blocks = keys.map((v) => {
        const items = groups.get(v).sort(sorters.spec);
        const cols = Math.max(1, Math.ceil(Math.sqrt(items.length)));
        const rows = Math.ceil(items.length / cols);
        return { v, items, cols, rows, w: Math.max(cols, MINW), h: rows };
      });
      const GX = multi ? 3 : 0, GY = multi ? 4 : 0;
      const area = blocks.reduce((s, b) => s + (b.w + GX) * (b.h + GY), 0);
      const rowW = Math.max(blocks.length ? Math.max(...blocks.map((b) => b.w)) : 10, Math.sqrt(area * aspect) * 1.05);
      const shelves = [];
      let shelf = { items: [], w: 0, h: 0 };
      for (const b of blocks) {
        if (shelf.items.length && shelf.w + b.w > rowW) { shelves.push(shelf); shelf = { items: [], w: 0, h: 0 }; }
        shelf.items.push(b); shelf.w += b.w + GX; shelf.h = Math.max(shelf.h, b.h);
      }
      if (shelf.items.length) shelves.push(shelf);
      let y = 0;
      for (const sh of shelves) {
        let x = Math.round((rowW - (sh.w - GX)) / 2);
        for (const b of sh.items) {
          const gi = groupBlocks.length;
          b.items.forEach((i, k) => {
            to.x[i] = x + (k % b.cols); to.y[i] = y + Math.floor(k / b.cols); to.a[i] = 1;
            delay[i] = (k / b.items.length) * STAGGER;
            groupOf[i] = gi;
          });
          let rep = b.items[0];
          for (const i of b.items) if (cloudScore(i) > cloudScore(rep)) rep = i;
          groupBlocks.push({ v: b.v, x, y, w: b.cols, h: b.rows, n: b.items.length, rep, d });
          if (multi) labels.push({ x, y, v: b.v, n: b.items.length, d, rep });
          x += b.w + GX;
        }
        y += sh.h + GY;
      }
      hideInactive();
    } else {
      const lp = S.mode === 'wheel' || S.mode === 'hl' ? localGrid(S.mode) : null;
      for (let i = 0; i < N; i++) {
        let p;
        if (lp && lp.has(i)) p = lp.get(i);
        else if (S.mode === 'wheel') p = R[i].wh;
        else if (S.mode === 'hl') p = R[i].hl;
        else { mapPos = mapPos || computeMapPos(); p = mapPos[i]; }
        to.x[i] = p[0]; to.y[i] = p[1]; to.a[i] = !base[i] ? 0 : active[i] ? 1 : DIM_A;
        delay[i] = (R[i].sp / N) * STAGGER;
      }
    }
    animStart = performance.now(); animating = true;
    labelsEl.replaceChildren(); labelsEl.dataset.k = '';
    if (!keepCamera) fitCamera();
    requestDraw();
    if (exploreReady) setTimeout(() => tellState(), 0);
  }

  // 範囲（研究台の筛选・記録集合）が資料庫の一部なら、色轮・色相×明度をその記録だけで
  // 並べ直す（全体の配置のままだと小さな範囲は疎らで小さくなる）。backend と同じ式・
  // 同じ「近い組から空いている格子へ」の割当。大きすぎる範囲は全体の配置を使う。
  const gridCache = new Map();
  let wheelR = 0;
  function localGrid(mode) {
    const ids = [];
    for (let i = 0; i < N; i++) if (base[i]) ids.push(i);
    if (ids.length === 0 || ids.length >= N - countGone() || ids.length > 1200) { if (mode === 'wheel') wheelR = 0; return null; }
    const key = mode + ':' + ids.length + ':' + ids[0] + ':' + ids[ids.length - 1] + ':' + ids[ids.length >> 1];
    if (gridCache.has(key)) { const c = gridCache.get(key); if (mode === 'wheel') wheelR = c.r; return c.pos; }
    const n = ids.length;
    const repOf = (i) => { const q = R[i].pal[R[i].rep]; return { L: R[i].chr ? q[2] : R[i].L, C: Math.hypot(q[3], q[4]), h: R[i].hue }; };
    let pts, cells, rr = 0;
    if (mode === 'wheel') {
      pts = ids.map((i) => {
        const c = repOf(i);
        if (!R[i].chr) return [0, (0.5 - c.L) * 0.36];
        const r = 0.28 + 0.72 * Math.min(1, c.C / 0.2);
        return [r * Math.cos((c.h * Math.PI) / 180), -r * Math.sin((c.h * Math.PI) / 180)];
      });
      rr = Math.sqrt(n / Math.PI) + 1.5;
      for (;;) {
        cells = [];
        const k = Math.ceil(rr);
        for (let y = -k; y <= k; y++) for (let x = -k; x <= k; x++) if (x * x + y * y <= rr * rr) cells.push([x, y]);
        if (cells.length >= n) break;
        rr += 0.5;
      }
      pts = pts.map(([x, y]) => [x * rr, y * rr]);
    } else {
      const rows = Math.max(1, Math.ceil(Math.sqrt(n / 2.4)));
      const cols = Math.ceil(n / rows) + 2;
      pts = ids.map((i) => {
        const c = repOf(i);
        const x = R[i].chr ? 0.09 + 0.91 * ((((c.h - 15) % 360) + 360) % 360) / 360 : 0.03;
        return [x * (cols - 1), (1 - c.L) * (rows - 1)];
      });
      cells = [];
      for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) cells.push([x, y]);
    }
    const m = cells.length;
    const cost = new Float64Array(n * m);
    for (let a = 0; a < n; a++) for (let b = 0; b < m; b++) {
      const dx = pts[a][0] - cells[b][0], dy = pts[a][1] - cells[b][1];
      cost[a * m + b] = dx * dx + dy * dy;
    }
    const order = new Uint32Array(n * m);
    for (let k = 0; k < order.length; k++) order[k] = k;
    order.sort((x, y) => cost[x] - cost[y]);
    const usedP = new Uint8Array(n), usedC = new Uint8Array(m), pos = new Map();
    let left = n;
    for (let k = 0; k < order.length && left; k++) {
      const a = (order[k] / m) | 0, b = order[k] % m;
      if (usedP[a] || usedC[b]) continue;
      usedP[a] = usedC[b] = 1; left--;
      pos.set(ids[a], cells[b]);
    }
    if (gridCache.size > 8) gridCache.clear();
    gridCache.set(key, { pos, r: rr });
    if (mode === 'wheel') wheelR = rr;
    return pos;
  }
  let goneN = -1;
  const countGone = () => { if (goneN < 0) { goneN = 0; for (let i = 0; i < N; i++) if (R[i].gone) goneN++; } return goneN; };

  function fitCamera(instant) {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity, any = false;
    for (let i = 0; i < N; i++) {
      if (to.a[i] < 0.5) continue;
      any = true;
      x0 = Math.min(x0, to.x[i]); y0 = Math.min(y0, to.y[i]);
      x1 = Math.max(x1, to.x[i] + to.s[i]); y1 = Math.max(y1, to.y[i] + to.s[i]);
    }
    if (!any) return;
    if (S.mode === 'group' && labels.length) y0 -= 3;
    if (S.mode === 'wheel') { x0 -= 3; x1 += 3; y0 -= 3; y1 += 3; }
    if (S.mode === 'map') { x0 -= 6; x1 += 6; y0 -= 10; y1 += 10; }
    const sr = safeRect();
    const aw = W - sr.l - sr.r, ah = H - sr.t - sr.b;
    const k = Math.min(aw / (x1 - x0), ah / (y1 - y0), 140);
    const target = { k, x: sr.l + aw / 2 - ((x0 + x1) / 2) * k, y: sr.t + ah / 2 - ((y0 + y1) / 2) * k };
    if (instant) { Object.assign(cam, target); Object.assign(camTo, target); camAnim = -1; requestDraw(); return; }
    Object.assign(camFrom, cam); Object.assign(camTo, target);
    camAnim = performance.now();
    requestDraw();
  }

  const hi = new Map();
  let loading = 0;
  function wantHi(r) {
    const h = hi.get(r.ph);
    if (h && h !== 'loading') return h;
    if (!h && loading < 16) {
      hi.set(r.ph, 'loading'); loading++;
      const im = new Image();
      im.onload = () => { hi.set(r.ph, im); loading--; requestDraw(); };
      im.onerror = () => { loading--; };
      im.src = TH + r.ph;
    }
    return null;
  }

  let raf = 0;
  function requestDraw() {
    if (raf) return;
    raf = requestAnimationFrame(frame);
    // some embedded / backgrounded webviews stall rAF; keep drawing anyway
    const id = raf;
    setTimeout(() => { if (raf === id) { cancelAnimationFrame(id); frame(performance.now()); } }, 100);
  }
  const ease = (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

  function frame(now) {
    raf = 0;
    if (S.view !== 'explore') return;
    let more = false;
    if (animating) {
      let done = true;
      for (let i = 0; i < N; i++) {
        let t = (now - animStart - delay[i]) / DUR;
        if (t < 1) done = false;
        t = ease(Math.max(0, Math.min(1, t)));
        cur.x[i] = from.x[i] + (to.x[i] - from.x[i]) * t;
        cur.y[i] = from.y[i] + (to.y[i] - from.y[i]) * t;
        cur.a[i] = from.a[i] + (to.a[i] - from.a[i]) * t;
        cur.s[i] = from.s[i] + (to.s[i] - from.s[i]) * t;
      }
      if (done) animating = false; else more = true;
    }
    if (camAnim >= 0) {
      const t = Math.min(1, (now - camAnim) / DUR), e = ease(t);
      cam.k = camFrom.k * Math.pow(camTo.k / camFrom.k, e);
      cam.x = camFrom.x + (camTo.x - camFrom.x) * e;
      cam.y = camFrom.y + (camTo.y - camFrom.y) * e;
      if (t >= 1) camAnim = -1; else more = true;
    }
    draw();
    if (more) requestDraw();
  }

  function drawTile(i, x, y, s, useHi) {
    if (useHi) {
      const im = wantHi(R[i]);
      if (im) {
        const m = Math.min(im.naturalWidth, im.naturalHeight);
        ctx.save();
        ctx.beginPath(); ctx.roundRect(x, y, s, s, s * RAD); ctx.clip();
        ctx.drawImage(im, (im.naturalWidth - m) / 2, (im.naturalHeight - m) / 2, m, m, x, y, s, s);
        ctx.restore();
        return;
      }
    }
    if (atlas.complete) ctx.drawImage(atlas, (i % ACOLS) * TILE, Math.floor(i / ACOLS) * TILE, TILE, TILE, x, y, s, s);
  }

  function draw() {
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0);
    ctx.clearRect(0, 0, W, H);
    ctx.setTransform(DPR * cam.k, 0, 0, DPR * cam.k, DPR * cam.x, DPR * cam.y);

    if (S.mode === 'map' && basemap.complete && basemap.naturalWidth) {
      ctx.globalAlpha = 0.85;
      ctx.drawImage(basemap, 0, 0, 1100 / MAP_S, 350 / MAP_S);
    }
    if (S.mode === 'wheel') drawWheelGuide();

    const vx0 = -cam.x / cam.k - 10, vy0 = -cam.y / cam.k - 10, vx1 = (W - cam.x) / cam.k, vy1 = (H - cam.y) / cam.k;
    const sel = S.selected;
    const related = sel != null ? new Set(R[sel].nb) : null;
    for (let i = 0; i < N; i++) {
      const a = cur.a[i];
      if (a < 0.01 || i === hover || i === sel || (related && related.has(i) && a > 0.3)) continue;
      const x = cur.x[i], y = cur.y[i], sz = cur.s[i] - GAP;
      if (x < vx0 || y < vy0 || x > vx1 || y > vy1) continue;
      ctx.globalAlpha = focusIdx >= 0 && S.mode === 'group' && groupOf[i] !== focusIdx ? a * 0.18 : a;
      drawTile(i, x, y, sz, !animating && cam.k * sz > 70);
    }
    // 近づいたら写真の上に必要な情報（言語・審核状態）。クリックで共通の详情。
    if (!animating && cam.k * (1 - GAP) >= 120) drawTileInfo(vx0, vy0, vx1, vy1);
    if (sel != null) {
      const p = ease(Math.min(1, (performance.now() - selT0) / 260));
      if (p < 1) requestDraw();
      // related (colour-similar) photos: a lighter version of the same lift
      for (const i of related) {
        if (i === hover || cur.a[i] <= 0.3) continue;
        const x = cur.x[i], y = cur.y[i];
        if (x < vx0 || y < vy0 || x > vx1 || y > vy1) continue;
        liftTile(i, 1 + 0.025 * p, 0.10 * p, 0.55 * p, false);
      }
      // selected: lifted card, soft shadow, white inner edge
      if (cur.a[sel] > 0.01) liftTile(sel, 1 + 0.07 * p, 0.10 + 0.14 * p, 1, true);
    }
    // 研究台で選択中の記録: 右上に小さな黒丸（拡大しても邪魔にならない大きさ）
    if (checked.size) {
      ctx.globalAlpha = 1;
      for (const i of checked) {
        if (cur.a[i] < 0.3) continue;
        const x = cur.x[i], y = cur.y[i], sz = cur.s[i] - GAP;
        if (x < vx0 || y < vy0 || x > vx1 || y > vy1) continue;
        const rr = Math.max(sz * 0.13, 4 / cam.k);
        ctx.fillStyle = '#0f0f0e';
        ctx.beginPath(); ctx.arc(x + sz - rr * 1.1, y + rr * 1.1, rr, 0, Math.PI * 2); ctx.fill();
        ctx.lineWidth = Math.max(1 / cam.k, rr * 0.28);
        ctx.strokeStyle = '#fff'; ctx.stroke();
      }
    }
    // hover: gentle lift; tiny tiles grow to a readable size
    if (hover != null && hover !== sel && cur.a[hover] > 0.01) {
      const base = cur.s[hover] - GAP, px = cam.k * base;
      liftTile(hover, px < 60 ? Math.min(2.4, 90 / px) : 1.04, 0.18, 0, false);
    }
    ctx.globalAlpha = 1;
    drawLabels();
  }
  const ST_LABEL = {
    zh: { pending: '待处理', ai: 'AI 草稿', 'human-reviewed': '已审核', final: '已确认' },
    ja: { pending: '未処理', ai: 'AI 下書き', 'human-reviewed': 'レビュー済み', final: '確定済み' },
  };
  function drawTileInfo(vx0, vy0, vx1, vy1) {
    let n = 0;
    for (let i = 0; i < N && n < 160; i++) {
      if (cur.a[i] < 0.5 || (focusIdx >= 0 && S.mode === 'group' && groupOf[i] !== focusIdx)) continue;
      const x = cur.x[i], y = cur.y[i], sz = cur.s[i] - GAP;
      if (x + sz < vx0 || y + sz < vy0 || x > vx1 || y > vy1) continue;
      n++;
      const r = R[i], band = sz * 0.2;
      ctx.globalAlpha = 1;
      ctx.save();
      ctx.beginPath(); ctx.roundRect(x, y, sz, sz, sz * RAD); ctx.clip();
      ctx.fillStyle = 'rgba(15,15,14,0.62)';
      ctx.fillRect(x, y + sz - band, sz, band);
      const fs = band * 0.42;
      ctx.font = `600 ${fs}px Inter, 'Hiragino Sans', 'Microsoft YaHei', sans-serif`;
      ctx.textBaseline = 'middle';
      ctx.fillStyle = '#fff';
      const langs = [...r.main].map((c) => c.toUpperCase()).join(' ') || '—';
      ctx.fillText(langs, x + fs * 0.7, y + sz - band / 2);
      const st = (ST_LABEL[LANG] || ST_LABEL.zh)[r.st] || '';
      if (st) {
        ctx.font = `${fs * 0.92}px Inter, 'Hiragino Sans', 'Microsoft YaHei', sans-serif`;
        ctx.textAlign = 'right';
        ctx.fillStyle = 'rgba(255,255,255,0.85)';
        ctx.fillText(st, x + sz - fs * 0.7, y + sz - band / 2);
        ctx.textAlign = 'left';
      }
      ctx.restore();
    }
  }
  let selT0 = 0;
  /** draw a tile "lifted": scale, drop shadow, optional white inner edge (edge = 0..1 strength) */
  function liftTile(i, scale, shadowA, edge, primary) {
    const base = cur.s[i] - GAP, s = base * scale;
    const x = cur.x[i] + base / 2 - s / 2, y = cur.y[i] + base / 2 - s / 2;
    ctx.globalAlpha = 1;
    if (shadowA > 0.005) {
      ctx.save();
      ctx.shadowColor = `rgba(0,0,0,${shadowA})`;
      ctx.shadowBlur = (primary ? 28 : 16) * DPR; ctx.shadowOffsetY = (primary ? 10 : 5) * DPR;
      ctx.fillStyle = '#fff';
      ctx.beginPath(); ctx.roundRect(x, y, s, s, s * RAD); ctx.fill();
      ctx.restore();
    }
    drawTile(i, x, y, s, primary || cam.k * s > 70);
    if (edge <= 0) return;
    const lw = Math.min((primary ? 3 : 1.75) / cam.k, s * (primary ? 0.06 : 0.04));
    ctx.lineWidth = lw;
    ctx.strokeStyle = `rgba(255,255,255,${0.95 * edge})`;
    ctx.beginPath(); ctx.roundRect(x + lw / 2, y + lw / 2, s - lw, s - lw, Math.max(0, s * RAD - lw / 2)); ctx.stroke();
    // when tiles are tiny the lift alone is hard to find: add a fine dark hairline
    if (cam.k * s < 34) {
      ctx.lineWidth = (primary ? 1.5 : 1) / cam.k;
      ctx.strokeStyle = `rgba(15,15,14,${primary ? 0.85 : 0.4 * edge})`;
      ctx.beginPath(); ctx.roundRect(x - 1 / cam.k, y - 1 / cam.k, s + 2 / cam.k, s + 2 / cam.k, s * RAD + 1 / cam.k); ctx.stroke();
    }
  }

  function drawWheelGuide() {
    let r = wheelR;
    if (!r) for (let i = 0; i < N; i++) r = Math.max(r, Math.hypot(R[i].wh[0], R[i].wh[1]));
    r += 1.8;
    const g = ctx.createConicGradient(0, 0.5, 0.5);
    for (let s = 0; s <= 24; s++) g.addColorStop(s / 24, `oklch(0.7 0.2 ${(360 - (s / 24) * 360) % 360})`);
    ctx.globalAlpha = 1;
    ctx.strokeStyle = g;
    ctx.lineWidth = 0.4;
    ctx.beginPath(); ctx.arc(0.5, 0.5, r, 0, Math.PI * 2); ctx.stroke();
  }

  function drawLabels() {
    if (S.mode !== 'group' || animating) return;
    const key = `${cam.x}|${cam.y}|${cam.k}`;
    if (labelsEl.dataset.k === key) return;
    labelsEl.dataset.k = key;
    const frag = document.createDocumentFragment();
    for (const l of labels) {
      const el = document.createElement('div');
      el.style.left = (l.x * cam.k + cam.x) + 'px';
      el.style.top = (l.y * cam.k + cam.y) + 'px';
      el.style.transform = 'translate(-6px, calc(-100% - 4px))';
      el.dataset.v = l.v;
      const sw = l.d.sw ? `<i class="sw" style="background:${l.d.sw(l.v)}"></i>` : '';
      const gi = groupBlocks.findIndex((g) => g.v === l.v);
      if (focusIdx >= 0 && gi !== focusIdx) el.className = 'dim';
      el.innerHTML = `<img src="${TH}${R[l.rep].ph}" alt="">${sw}<b>${esc(fmtVal(l.d, l.v))}</b><span class="n">${l.n}</span>`;
      frag.appendChild(el);
    }
    labelsEl.replaceChildren(frag);
  }
  // 組名をクリック → その組へ入る（カメラを寄せ、他の組は薄く）。もう一度で全貌。
  labelsEl.addEventListener('click', (e) => {
    const el = e.target.closest('[data-v]');
    if (!el) return;
    const gi = groupBlocks.findIndex((g) => g.v === el.dataset.v);
    focusGroup(gi === focusIdx ? -1 : gi);
  });
  function focusGroup(gi) {
    focusIdx = gi;
    labelsEl.dataset.k = '';
    if (gi < 0) { fitCamera(); tellState(); requestDraw(); return; }
    const g = groupBlocks[gi];
    const sr = safeRect();
    const aw = W - sr.l - sr.r, ah = H - sr.t - sr.b;
    const x0 = g.x - 0.5, y0 = g.y - 3, x1 = g.x + g.w + 0.5, y1 = g.y + g.h + 0.5;
    const k = Math.min(aw / (x1 - x0), ah / (y1 - y0), 160);
    Object.assign(camFrom, cam);
    Object.assign(camTo, { k, x: sr.l + aw / 2 - ((x0 + x1) / 2) * k, y: sr.t + ah / 2 - ((y0 + y1) / 2) * k });
    camAnim = performance.now();
    tellState();
    requestDraw();
  }

  // interaction
  let hover = null, drag = null, moved = false;
  const tip = $('tip');
  function hit(mx, my) {
    const wx = (mx - cam.x) / cam.k, wy = (my - cam.y) / cam.k;
    let best = null;
    for (let i = 0; i < N; i++) {
      if (cur.a[i] < 0.3) continue;
      const sz = cur.s[i] - GAP;
      if (wx >= cur.x[i] && wx <= cur.x[i] + sz && wy >= cur.y[i] && wy <= cur.y[i] + sz) best = i;
    }
    return best;
  }
  const local = (e) => { const b = cv.getBoundingClientRect(); return [e.clientX - b.left, e.clientY - b.top]; };
  cv.addEventListener('pointerdown', (e) => {
    drag = { x: e.clientX, y: e.clientY, cx: cam.x, cy: cam.y }; moved = false;
    cv.setPointerCapture(e.pointerId);
  });
  cv.addEventListener('pointermove', (e) => {
    if (drag) {
      const dx = e.clientX - drag.x, dy = e.clientY - drag.y;
      if (Math.abs(dx) + Math.abs(dy) > 4) { moved = true; cv.classList.add('dragging'); }
      if (moved) { camAnim = -1; cam.x = drag.cx + dx; cam.y = drag.cy + dy; hover = null; hideTip(); requestDraw(); return; }
    }
    const [mx, my] = local(e);
    const h = hit(mx, my);
    if (h !== hover) { hover = h; requestDraw(); }
    cv.classList.toggle('over', h != null);
    if (h != null) showTip(h, e.clientX, e.clientY); else hideTip();
  });
  cv.addEventListener('pointerup', (e) => {
    cv.classList.remove('dragging');
    if (drag && !moved) {
      const [mx, my] = local(e);
      const h = hit(mx, my);
      if (h != null) select(h, true);
    }
    drag = null;
  });
  cv.addEventListener('pointerleave', () => { hover = null; hideTip(); requestDraw(); });
  cv.addEventListener('dblclick', (e) => { const [mx, my] = local(e); if (hit(mx, my) == null) { if (focusIdx >= 0) focusGroup(-1); else fitCamera(); } });
  cv.addEventListener('wheel', (e) => {
    e.preventDefault();
    camAnim = -1;
    const [mx, my] = local(e);
    const f = Math.exp(-e.deltaY * (e.ctrlKey ? 0.01 : 0.0015));
    const k = Math.max(1, Math.min(400, cam.k * f));
    cam.x = mx - (mx - cam.x) * (k / cam.k);
    cam.y = my - (my - cam.y) * (k / cam.k);
    cam.k = k;
    hideTip(); requestDraw();
  }, { passive: false });

  function showTip(i, cx, cy) {
    const r = R[i];
    if (tip.dataset.i !== String(i)) {
      tip.dataset.i = i;
      tip.innerHTML = `<div>${r.main.map(langName).join(' · ') || t('tip.nolang')} · ${cnl(r.cn)}</div><div class="t2">${esc(vf(r.f.dis))} · ${esc(vf(r.f.car))}</div>${palHTML(r)}`;
    }
    tip.hidden = false;
    const tw = tip.offsetWidth, th = tip.offsetHeight;
    let x = cx + 18, y = cy + 18;
    if (x + tw > innerWidth - 8) x = cx - tw - 18;
    if (y + th > innerHeight - 8) y = cy - th - 18;
    tip.style.left = x + 'px'; tip.style.top = y + 'px';
  }
  function hideTip() { tip.hidden = true; }

  const groupSel = $('group');
  groupSel.innerHTML = DIMS.map((d) => `<option value="${d.key}">${d.label}</option>`).join('');
  let themeScrollUpdate = null;
  function setMode(m) {
    if (!['wall', 'group', 'wheel', 'hl', 'map'].includes(m)) m = 'wall';
    S.mode = m;
    document.querySelectorAll('#modes button').forEach((b) => b.classList.toggle('on', b.dataset.mode === m));
    $('ctl-sort').style.display = m === 'wall' ? '' : 'none';
    $('ctl-group').style.display = m === 'group' ? '' : 'none';
    if (exploreReady) layout();
    writeHash();
    tellState();
  }
  document.querySelectorAll('#modes button').forEach((b) => (b.onclick = () => setMode(b.dataset.mode)));
  $('sort').onchange = (e) => { S.sort = e.target.value; layout(); writeHash(); };
  groupSel.onchange = (e) => { S.group = e.target.value; layout(); writeHash(); };

  function enterExplore() {
    resize();
    if (!exploreReady) {
      exploreReady = true;
      lastW = W; lastH = H;
      layout();
      fitCamera(true);
      const cx = (W / 2 - cam.x) / cam.k, cy = (H / 2 - cam.y) / cam.k;
      for (let i = 0; i < N; i++) {
        const ang = Math.random() * Math.PI * 2, rr = Math.random() * 8;
        from.x[i] = cur.x[i] = cx + Math.cos(ang) * rr; from.y[i] = cur.y[i] = cy + Math.sin(ang) * rr; from.a[i] = cur.a[i] = 0;
      }
      animStart = performance.now(); animating = true;
    }
    requestDraw();
  }

  // ================================================================ detail card
  const detail = $('detail');
  function select(i, push) {
    if (S.selected !== i) selT0 = performance.now();
    S.selected = i;
    if (EMBED) {
      // 詳情は研究台の共通の記録详情で開く（ここでは選んだ写真を浮かせて示すだけ）。
      requestDraw();
      post({ type: 'llmap:open', rid: R[i].rid });
      return;
    }
    if (push) {
      const at = S.trail.indexOf(i);
      if (at >= 0) S.trail.splice(at, 1);
      S.trail.push(i);
      if (S.trail.length > 40) S.trail.shift();
    }
    const wasHidden = detail.hidden;
    renderDetail();
    detail.hidden = false;
    document.body.classList.add('detail-open');
    // the card takes space on the right: re-flow the canvas so nothing hides underneath
    if (wasHidden && S.view === 'explore' && exploreReady) layout();
    requestDraw();
    writeHash();
  }
  function closeDetail() {
    if (EMBED) { S.selected = null; requestDraw(); return; }
    const wasOpen = !detail.hidden;
    S.selected = null; detail.hidden = true;
    document.body.classList.remove('detail-open');
    if (wasOpen && S.view === 'explore' && exploreReady) layout();
    requestDraw(); writeHash();
  }
  $('detail-close').onclick = closeDetail;
  addEventListener('keydown', (e) => { if (e.key === 'Escape' && document.activeElement !== $('search')) closeDetail(); });

  function renderDetail() {
    const i = S.selected, r = R[i];
    $('trail').innerHTML = S.trail.map((j) => `<button class="${j === i ? 'cur' : ''}" data-i="${j}" title="${R[j].d}" style="background-image:url('${TH}${R[j].ph}')"></button>`).join('');
    $('trail').querySelectorAll('button').forEach((b) => (b.onclick = () => select(+b.dataset.i, false)));
    $('trail').scrollLeft = 1e6;
    const langs = (arr) => (arr.length ? arr.map((c) => `<span class="lang"><i style="background:${langColor(c)}"></i>${langName(c)}</span>`).join('') : '—');
    const note = (r.note || '').replace(/^【判断】/, '');
    const inChain = S.view === 'chain';
    const body = $('detail-body');
    body.innerHTML = `
      <img class="hero-img" src="${TH}${r.ph}" alt="">
      <p class="did"><span>${r.d}</span><span>${r.t.slice(0, 16)}</span></p>
      <div class="palette-big">${r.pal.map((q) => `<i style="background:${q[0]};flex:${q[1]}" title="${q[0]}"></i>`).join('')}</div>
      <div class="palette-legend">${r.pal.map((q) => `<span><i class="sw" style="background:${q[0]}"></i>${q[0]}<em>${Math.round(q[1] * 100)}% ${cnl(q[5])}</em></span>`).join('')}</div>
      <div class="stats">
        <div><b><i style="background:${repHex(r)}"></i>${cnl(r.cn)}</b>${t('d.rep')}</div>
        <div><b>${Math.round(r.cf * 100)}</b>${t('d.cf')}</div>
        <div><b>${Math.round(r.L * 100)}</b>${t('d.L')}</div>
      </div>
      <div class="actions">
        ${window.LLV_EMBED && r.rid ? `<button class="pill dark sm" id="act-research">${t('d.research')}</button>` : ''}
        ${inChain ? `<button class="pill light sm" id="act-explore">${t('d.toExplore')}</button>` : `<button class="pill dark sm" id="act-chain">${t('d.chain')}</button><button class="pill light sm" id="act-pick">${t('d.pick')}</button>`}
      </div>
      <dl class="fields">
        <dt>${t('dim.lang')}</dt><dd>${langs(r.main)}</dd>
        <dt>${t('dim.aux')}</dt><dd>${langs(r.aux)}</dd>
        <dt>${t('dim.rel')}</dt><dd>${esc(vf(r.f.rel))}</dd>
        <dt>${t('dim.dis')}</dt><dd>${esc(vf(r.f.dis))}</dd>
        <dt>${t('dim.car')}</dt><dd>${esc(vf(r.f.car))}</dd>
        <dt>${t('dim.pos')}</dt><dd>${esc(vf(r.f.pos))}</dd>
        <dt>${t('dim.tmp')}</dt><dd>${esc(vf(r.f.tmp))}</dd>
        <dt>${t('dim.rd')}</dt><dd>${esc(vf(r.f.rd))}</dd>
        <dt>${t('dim.q')}</dt><dd>${esc(vf(r.f.q))}</dd>
      </dl>
      ${note ? `<div class="note">${esc(note)}</div>` : ''}
      ${inChain ? '' : `<div id="detail-next">${nextHTML(i, S.rel && S.rel.i === i ? S.rel.key : null)}</div>`}
    `;
    const research = $('act-research');
    if (research) research.onclick = () => window.parent.postMessage({ type: 'llmap:openRecord', rid: r.rid }, '*');
    if (inChain) {
      $('act-explore').onclick = () => { go('explore'); setTimeout(() => select(i, false), 600); };
    } else {
      $('act-chain').onclick = () => { chainStartFrom(i); go('chain'); };
      $('act-pick').onclick = () => { $('pick-color').value = repHex(r); applyPick(); };
      bindNext($('detail-next'), i,
        (key, rerender) => {
          if (key) { S.rel = S.rel && S.rel.i === i && S.rel.key === key ? null : { i, key }; recompute(); }
          renderDetail();
          if (rerender) $('detail-next').scrollIntoView({ block: 'nearest' });
        },
        (j) => { select(j, true); body.scrollTop = 0; });
    }
  }

  // ================================================================ landing
  const floaters = $('floaters');
  function buildFloaters() {
    const w = innerWidth, h = Math.max(620, innerHeight);
    const mobile = w < 720;
    const count = mobile ? 14 : 34;
    const pool = R.map((_, i) => i).filter((i) => R[i].chr && R[i].cf > 0.28).sort((a, b) => R[a].sp - R[b].sp);
    const greys = R.map((_, i) => i).filter((i) => !R[i].chr && R[i].L > 0.35 && R[i].L < 0.85);
    const picks = [];
    const nCol = Math.round(count * 0.9);
    for (let k = 0; k < nCol; k++) picks.push(pool[Math.floor((k + Math.random() * 0.8) / nCol * pool.length)]);
    while (picks.length < count) picks.push(greys[Math.floor(Math.random() * greys.length)]);
    picks.sort(() => Math.random() - 0.5);

    const cols = mobile ? 4 : 10, rows = mobile ? 7 : 6;
    let cells = [];
    for (let r = 0; r < rows; r++) for (let c = 0; c < cols; c++) {
      const cx = (c + 0.5) / cols, cy = (r + 0.5) / rows;
      const inCenter = Math.abs(cx - 0.5) < (mobile ? 0.42 : 0.3) && Math.abs(cy - 0.5) < (mobile ? 0.24 : 0.3);
      const inNav = cy < 0.1 && (cx < 0.25 || cx > 0.85);
      if (!inCenter && !inNav) cells.push([c, r]);
    }
    cells.sort(() => Math.random() - 0.5);
    cells = cells.slice(0, count);

    const frag = document.createDocumentFragment();
    picks.slice(0, cells.length).forEach((i, k) => {
      const [c, r] = cells[k];
      const d = Math.random();
      const base = mobile ? 46 : 58;
      const wpx = base + d * (mobile ? 40 : 74);
      const aspect = [1.32, 0.8, 1, 1.22, 0.9][k % 5];
      const hpx = wpx / aspect;
      const x = ((c + rand(0.15, 0.85)) / cols) * w - wpx / 2;
      const y = ((r + rand(0.15, 0.85)) / rows) * h - hpx / 2;
      const ox = (x + wpx / 2 - w / 2) * 1.2, oy = (y + hpx / 2 - h / 2) * 1.2;
      const el = document.createElement('div');
      el.className = 'fl';
      el.style.cssText = `--x:${x}px;--y:${y}px;--d:${d.toFixed(2)};--ox:${ox}px;--oy:${oy}px;--in-delay:${rand(0, 0.9).toFixed(2)}s;z-index:${Math.round(d * 10)}`;
      el.innerHTML = `<div class="fl-in" style="--w:${wpx}px;--h:${hpx}px;--rx:${rand(-28, 28).toFixed(1)}deg;--ry:${rand(-28, 28).toFixed(1)}deg;--rz:${rand(-24, 24).toFixed(1)}deg;--blur:${d < 0.3 ? ((0.3 - d) * 14).toFixed(1) : 0}px;--op:${(0.4 + 0.6 * d).toFixed(2)};--dur:${rand(6, 13).toFixed(1)}s;--delay:${rand(-10, 0).toFixed(1)}s"><img src="${TH}${R[i].ph}" alt="" decoding="async"></div>`;
      el.onclick = () => { go('explore'); setTimeout(() => select(i, true), 650); };
      frag.appendChild(el);
    });
    floaters.classList.remove('in');
    floaters.replaceChildren(frag);
    void floaters.offsetWidth;
    setTimeout(() => floaters.classList.add('in'), 40);
  }
  $('landing').addEventListener('pointermove', (e) => {
    floaters.style.setProperty('--mx', ((e.clientX / innerWidth) - 0.5) * 2);
    floaters.style.setProperty('--my', ((e.clientY / innerHeight) - 0.5) * 2);
  });
  $('scroll-cue').onclick = () => $('themes').scrollIntoView({ behavior: 'smooth' });
  let flTimer = 0, flW = innerWidth;
  addEventListener('resize', () => {
    clearTimeout(flTimer);
    flTimer = setTimeout(() => { if (Math.abs(innerWidth - flW) > 80) { flW = innerWidth; buildFloaters(); } }, 300);
  });

  // themes — curated filter presets, shown as Arts & Culture style cards
  const THEMES = [
    { id: 1, sel: { lang: ['zh'], cn: ['red'] }, mode: 'group', group: 'dis' },
    { id: 2, sel: { q: ['手作'] }, mode: 'group', group: 'cn' },
    { id: 3, sel: { tmp: ['临时·季节性'] }, mode: 'group', group: 'cn' },
    { id: 4, sel: { dis: ['规约性话语'] }, mode: 'group', group: 'cn' },
    { id: 5, sel: { rel: ['复制型'] }, mode: 'group', group: 'lang' },
    { id: 6, sel: { lang: ['vi', 'ne'] }, mode: 'group', group: 'lang' },
    { id: 7, range: { cf: [0.72, 1] }, mode: 'group', group: 'cn' },
    { id: 8, sel: { cn: ['black'] }, mode: 'group', group: 'dis' },
    { id: 9, sel: { car: ['贴纸', '便签'] }, mode: 'group', group: 'cn' },
  ];
  function themeMatches(t) {
    const out = [];
    for (let i = 0; i < N; i++) {
      if (R[i].gone) continue;
      let ok = true;
      for (const [k, vs] of Object.entries(t.sel || {})) if (!VAL[k][i].some((v) => vs.includes(v))) { ok = false; break; }
      for (const [k, [lo, hi]] of Object.entries(t.range || {})) if (R[i][k] < lo || R[i][k] > hi) ok = false;
      if (ok) out.push(i);
    }
    return out.sort((a, b) => cloudScore(b) - cloudScore(a));
  }
  function buildThemes() {
    const row = $('th-row');
    const used = new Set();
    row.innerHTML = THEMES.map((t, k) => {
      const all = themeMatches(t);
      if (!all.length) return '';
      t.count = all.length;
      // avoid repeating the same photos across neighbouring theme cards
      const m = all.filter((j) => !used.has(j)).concat(all.filter((j) => used.has(j)));
      m.slice(0, 4).forEach((j) => used.add(j));
      const strip = m.slice(1, 4).map((j) => `<i style="background-image:url('${TH}${R[j].ph}')"></i>`).join('');
      return `<button class="th" data-k="${k}" style="background-image:url('${TH}${R[m[0]].ph}')">
        <span class="badge-l">${ICON.theme}${tr('themes.badge', { n: m.length })}</span>
        <span class="strip">${strip}</span>
        <span class="t"><b>${esc(tr(`th.${t.id}.t`))}</b><small>${esc(tr(`th.${t.id}.s`))}</small></span></button>`;
    }).join('');
    row.querySelectorAll('.th').forEach((b) => (b.onclick = () => openTheme(THEMES[+b.dataset.k])));
  }
  // horizontal carousel: drag, wheel/trackpad, arrow buttons, progress bar
  function setupThemeScroll() {
    const row = $('th-row'), wrap = $('th-wrap'), bar = $('th-bar');
    const step = () => Math.max(300, row.clientWidth * 0.8);
    const update = () => {
      const max = row.scrollWidth - row.clientWidth;
      const p = max > 0 ? row.scrollLeft / max : 0;
      const vis = max > 0 ? row.clientWidth / row.scrollWidth : 1;
      bar.style.width = vis * 100 + '%';
      bar.style.transform = `translateX(${(p * (1 - vis) / vis) * 100}%)`;
      wrap.classList.toggle('at-start', row.scrollLeft < 4);
      wrap.classList.toggle('at-end', row.scrollLeft > max - 4);
      $('th-prev').disabled = row.scrollLeft < 4;
      $('th-next').disabled = row.scrollLeft > max - 4;
    };
    $('th-prev').onclick = () => row.scrollBy({ left: -step(), behavior: 'smooth' });
    $('th-next').onclick = () => row.scrollBy({ left: step(), behavior: 'smooth' });
    row.addEventListener('scroll', update, { passive: true });
    addEventListener('resize', update);
    // mouse wheel: vertical wheel scrolls the row sideways until it reaches an end
    // 研究台の首页に埋め込まれているとき: 縦のホイールはページのスクロールへ渡す
    // （主题の列が奪うと、首页が下へ進まなくなる）。横へは掴んで動かす／横スワイプ。
    if (EMBED) {
      $('landing').addEventListener('wheel', (e) => {
        if (Math.abs(e.deltaX) > Math.abs(e.deltaY)) return;
        e.preventDefault();
        post({ type: 'llmap:wheel', dy: e.deltaMode === 1 ? e.deltaY * 32 : e.deltaY });
      }, { passive: false });
    }
    row.addEventListener('wheel', (e) => {
      if (EMBED) return;
      if (Math.abs(e.deltaX) > Math.abs(e.deltaY)) return; // trackpad horizontal swipe: native
      const max = row.scrollWidth - row.clientWidth;
      if ((e.deltaY < 0 && row.scrollLeft <= 0) || (e.deltaY > 0 && row.scrollLeft >= max - 1)) return;
      e.preventDefault();
      row.scrollLeft += e.deltaY;
    }, { passive: false });
    // drag with the mouse (touch already scrolls natively)
    let d = null;
    row.addEventListener('pointerdown', (e) => {
      if (e.pointerType !== 'mouse' || e.button !== 0) return;
      d = { x: e.clientX, left: row.scrollLeft, moved: false, id: e.pointerId };
    });
    row.addEventListener('pointermove', (e) => {
      if (!d) return;
      const dx = e.clientX - d.x;
      if (!d.moved && Math.abs(dx) > 5) { d.moved = true; row.setPointerCapture(d.id); row.classList.add('dragging'); }
      if (d.moved) row.scrollLeft = d.left - dx;
    });
    const end = () => {
      if (!d) return;
      if (d.moved) {
        // swallow the click that follows a drag so it doesn't open a theme
        const stop = (ev) => { ev.stopPropagation(); ev.preventDefault(); };
        row.addEventListener('click', stop, { capture: true, once: true });
        setTimeout(() => row.removeEventListener('click', stop, { capture: true }), 50);
      }
      row.classList.remove('dragging');
      d = null;
    };
    row.addEventListener('pointerup', end);
    row.addEventListener('pointercancel', end);
    row.addEventListener('dragstart', (e) => e.preventDefault());
    update();
    setTimeout(update, 300);
    return update;
  }

  function themeConds(t) {
    const out = [];
    for (const [k, vs] of Object.entries(t.sel || {})) out.push(`${DIM[k].label}: ${vs.map((v) => fmtVal(DIM[k], v)).join(' / ')}`);
    for (const [k, [lo, hi]] of Object.entries(t.range || {})) {
      const rg = RANGES.find((x) => x.key === k);
      out.push(`${rg ? rg.label : k} ${Math.round(lo * 100)}–${Math.round(hi * 100)}`);
    }
    return out;
  }
  function openTheme(t) {
    if (EMBED) {
      // 主题＝一組の記録への入口: 研究台が「記録集合」として受け取り、条件と件数を示して
      // 照片・地図・照片云などで見られるようにする。
      post({ type: 'llmap:theme', id: t.id, title: tr(`th.${t.id}.t`), sub: tr(`th.${t.id}.s`), conds: themeConds(t),
        mode: t.mode || 'group', group: t.group || 'cn', rids: themeMatches(t).map((i) => R[i].rid) });
      return;
    }
    clearFilters();
    for (const [k, vs] of Object.entries(t.sel || {})) S.sel[k] = new Set(vs);
    for (const [k, r] of Object.entries(t.range || {})) S.range[k] = r.slice();
    if (t.group) { S.group = t.group; groupSel.value = t.group; }
    S.theme = t;
    setMode(t.mode || 'group');
    recompute({ keepTheme: true });
    go('explore');
  }

  // ================================================================ chain board (exploration map)
  const board = $('board'), world = $('world'), linksSvg = $('links');
  const NW = 168, ANCHOR_Y = 65, GX = 260, GY = 196;
  const CH = { nodes: [], links: [], active: null, ghosts: [], rel: 'color', cam: { x: 0, y: 0, k: 1 }, uid: 1 };
  const nodeById = (id) => CH.nodes.find((n) => n.id === id);

  function nodeHTML(i, tag) {
    const r = R[i];
    return `<img src="${TH}${r.ph}" alt="">${tag ? `<span class="tagline">${esc(tag)}</span>` : ''}${palHTML(r, 'np')}<div class="nc"><b>${r.main.map(langName).join(t('langsep')) || '—'}</b><span>${cnl(r.cn)} · ${esc(shortDis(r.f.dis))}</span></div>`;
  }
  function makeNodeEl(n, ghost, tag) {
    const el = document.createElement('div');
    el.className = 'node' + (ghost ? ' ghost' : '');
    el.innerHTML = nodeHTML(n.i, tag) + (ghost ? '' : `<button class="del" aria-label="${t('chain.remove')}">${X_SVG}</button>`);
    el.style.left = n.x + 'px'; el.style.top = n.y + 'px';
    world.appendChild(el);
    n.el = el;
    if (ghost) el.onclick = (e) => { e.stopPropagation(); commitGhost(n); };
    else {
      el.querySelector('.del').onclick = (e) => { e.stopPropagation(); removeNode(n); };
      bindNodeDrag(n);
    }
    return el;
  }
  function addNode(i, parent, x, y, rel) {
    const n = { id: CH.uid++, i, x, y };
    CH.nodes.push(n);
    makeNodeEl(n);
    if (parent) CH.links.push({ a: parent.id, b: n.id, rel: rel || 'color', fresh: true });
    return n;
  }
  function removeNode(n) {
    n.el.remove();
    CH.nodes = CH.nodes.filter((m) => m !== n);
    const parentLink = CH.links.find((l) => l.b === n.id);
    CH.links = CH.links.filter((l) => l.a !== n.id && l.b !== n.id);
    setActive(parentLink ? nodeById(parentLink.a) : null);
    saveChain();
  }
  function setActive(n) {
    CH.active = n ? n.id : null;
    CH.nodes.forEach((m) => m.el.classList.toggle('active', m === n));
    markRoots();
    if (n && !relOf(n.i, CH.rel)) CH.rel = 'color';
    rebuildGhosts();
    renderLinks();
    renderChainTitle();
    renderNextPanel();
    saveChain();
  }
  function markRoots() {
    const hasParent = new Set(CH.links.map((l) => l.b));
    CH.nodes.forEach((m) => m.el.classList.toggle('root', !hasParent.has(m.id)));
  }
  const overlaps = (x, y, except) => CH.nodes.some((m) => m !== except && Math.abs(m.x - x) < NW + 16 && Math.abs(m.y - y) < GY - 10);
  function freeSlot(n, taken = []) {
    const x = n.x + GX;
    for (let s = 0; s < 40; s++) {
      const off = (s % 2 ? 1 : -1) * Math.ceil(s / 2) * (GY / 2);
      const y = n.y + off;
      if (!overlaps(x, y) && !taken.some((t) => Math.abs(t - y) < GY - 10) && !CH.ghosts.some((g) => Math.abs(g.y - y) < GY - 10 && Math.abs(g.x - x) < NW)) return [x, y];
    }
    return [x, n.y];
  }
  function rebuildGhosts() {
    CH.ghosts.forEach((g) => g.el.remove());
    CH.ghosts = [];
    const n = nodeById(CH.active);
    if (!n) return;
    const rel = relOf(n.i, CH.rel);
    if (!rel) return;
    const onBoard = new Set(CH.nodes.map((m) => m.i));
    const cands = rel.all.filter((j) => !onBoard.has(j)).slice(0, 5);
    const taken = [];
    cands.forEach((j, k) => {
      const x = n.x + GX;
      let y = n.y + (k - (cands.length - 1) / 2) * GY;
      let guard = 0;
      while ((overlaps(x, y) || taken.some((t) => Math.abs(t - y) < GY - 10)) && guard++ < 30) y += GY / 2;
      taken.push(y);
      const g = { i: j, x, y, parent: n.id, rel: rel.key };
      makeNodeEl(g, true, rel.tag(j));
      CH.ghosts.push(g);
    });
  }
  function commitGhost(g) {
    const parent = nodeById(g.parent);
    const n = addNode(g.i, parent, g.x, g.y, g.rel);
    setActive(n);
    ensureVisible(n);
  }
  function addChildOf(parent, j, relKey) {
    const existing = CH.nodes.find((m) => m.i === j);
    if (existing) { setActive(existing); ensureVisible(existing); return; }
    CH.ghosts.forEach((g) => g.el.remove()); CH.ghosts = [];
    const [x, y] = freeSlot(parent);
    const n = addNode(j, parent, x, y, relKey);
    setActive(n);
    ensureVisible(n);
  }

  function anchor(n, side) { return [side === 'r' ? n.x + NW : n.x, n.y + ANCHOR_Y]; }
  function linkPath(a, b) {
    let p0, p3;
    if (b.x >= a.x + NW / 2) { p0 = anchor(a, 'r'); p3 = anchor(b, 'l'); }
    else { p0 = anchor(a, 'l'); p3 = anchor(b, 'r'); }
    const dir = p3[0] >= p0[0] ? 1 : -1;
    const c = Math.max(60, Math.abs(p3[0] - p0[0]) * 0.5);
    const p1 = [p0[0] + c * dir, p0[1]], p2 = [p3[0] - c * dir, p3[1]];
    const mid = [0, 1].map((k) => 0.125 * p0[k] + 0.375 * p1[k] + 0.375 * p2[k] + 0.125 * p3[k]);
    return { d: `M${p0[0]},${p0[1]} C${p1[0]},${p1[1]} ${p2[0]},${p2[1]} ${p3[0]},${p3[1]}`, mid };
  }
  const textW = (s) => [...s].reduce((w, c) => w + (c.charCodeAt(0) > 255 ? 11 : 6.6), 0);
  function badge(aI, bI, relKey, mid, ghost) {
    const rel = relOf(aI, relKey);
    const info = rel ? rel.link(bI) : { dot: sharedColor(aI, bI) };
    if (info.dot) return `<circle cx="${mid[0]}" cy="${mid[1]}" r="${ghost ? 5 : 7}" fill="${info.dot}"${ghost ? ' opacity=".75"' : ''}/>`;
    const w = textW(info.text) + 16;
    return `<g transform="translate(${mid[0]},${mid[1]})"><rect class="lb${ghost ? ' g' : ''}" x="${-w / 2}" y="-10" width="${w}" height="20" rx="10"/><text class="${ghost ? 'g' : ''}" y="4" text-anchor="middle">${esc(info.text)}</text></g>`;
  }
  function renderLinks() {
    let paths = '', badges = '';
    for (const l of CH.links) {
      const a = nodeById(l.a), b = nodeById(l.b);
      if (!a || !b) continue;
      const { d, mid } = linkPath(a, b);
      paths += `<path d="${d}" class="${l.fresh ? 'lk-new' : ''}"/>`;
      badges += badge(a.i, b.i, l.rel, mid, false);
      l.fresh = false;
    }
    for (const g of CH.ghosts) {
      const a = nodeById(g.parent);
      const { d, mid } = linkPath(a, g);
      paths += `<path d="${d}" class="ghost"/>`;
      badges += badge(a.i, g.i, g.rel, mid, true);
    }
    linksSvg.innerHTML = paths + badges;
  }
  function renderChainTitle() {
    const n = CH.nodes.length;
    $('chain-empty').hidden = n > 0;
    $('chain-title').hidden = n === 0;
    const kinds = new Set(CH.links.map((l) => l.rel));
    const dots = CH.nodes.slice(-10).map((m) => `<i style="background:${repHex(R[m.i])}"></i>`).join('');
    $('chain-title').innerHTML = `<span class="dots">${dots}</span><b>${t('chain.title')}</b><span>${t('chain.stats', { n, k: kinds.size || 0 })}</span>`;
  }

  // right-hand "接下来探索什么？" panel
  function renderNextPanel() {
    const n = nodeById(CH.active);
    const panel = $('next');
    panel.hidden = !n || S.view !== 'chain';
    if (!n) return;
    const r = R[n.i];
    $('next-head').innerHTML = `<span class="me" style="background-image:url('${TH}${r.ph}')"></span>
      <span class="who"><b>${esc(r.main.map(langName).join(' · ') || t('nolang'))} · ${cnl(r.cn)}</b>${esc(vf(r.f.dis))} · ${esc(vf(r.f.car))}</span>
      <button class="round" id="next-info" title="详情"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="8.5"/><path d="M12 11v5M12 8h.01"/></svg></button>`;
    $('next-info').onclick = () => select(n.i, true);
    $('next-body').innerHTML = nextHTML(n.i, CH.rel);
    bindNext($('next-body'), n.i,
      (key) => {
        if (key) CH.rel = key;
        rebuildGhosts(); renderLinks(); renderNextPanel(); ensureVisible(n);
      },
      (j, key) => addChildOf(n, j, key));
  }

  // camera
  function applyBoardCam() {
    const c = CH.cam;
    world.style.transform = `translate(${c.x}px, ${c.y}px) scale(${c.k})`;
    board.style.setProperty('--gs', 24 * c.k + 'px');
    board.style.setProperty('--gx', c.x + 'px');
    board.style.setProperty('--gy', c.y + 'px');
  }
  function bounds(list) {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (const n of list) { x0 = Math.min(x0, n.x); y0 = Math.min(y0, n.y); x1 = Math.max(x1, n.x + NW); y1 = Math.max(y1, n.y + 180); }
    return { x0, y0, x1, y1 };
  }
  const boardSafe = () => ({ top: navH() + 64, bottom: 110, left: 48, right: !$('next').hidden && innerWidth > 720 ? 410 : 48 });
  let boardAnim = 0;
  function animateCam(target) {
    const fromC = { ...CH.cam }, t0 = performance.now();
    cancelAnimationFrame(boardAnim);
    const step = (now) => {
      const t = Math.min(1, (now - t0) / 700), e = ease(t);
      CH.cam.k = fromC.k * Math.pow(target.k / fromC.k, e);
      CH.cam.x = fromC.x + (target.x - fromC.x) * e;
      CH.cam.y = fromC.y + (target.y - fromC.y) * e;
      applyBoardCam();
      if (t < 1) boardAnim = requestAnimationFrame(step);
    };
    boardAnim = requestAnimationFrame(step);
    setTimeout(() => { if (CH.cam.k !== target.k || CH.cam.x !== target.x) { Object.assign(CH.cam, target); applyBoardCam(); } }, 900);
  }
  function fitBoard(instant) {
    const list = [...CH.nodes, ...CH.ghosts];
    if (!list.length) return;
    const b = bounds(list), sf = boardSafe();
    const bw = board.clientWidth - sf.left - sf.right, bh = board.clientHeight - sf.top - sf.bottom;
    const k = Math.max(0.45, Math.min(bw / (b.x1 - b.x0), bh / (b.y1 - b.y0), 1.1));
    const target = { k, x: sf.left + bw / 2 - ((b.x0 + b.x1) / 2) * k, y: sf.top + bh / 2 - ((b.y0 + b.y1) / 2) * k };
    if (instant) { Object.assign(CH.cam, target); applyBoardCam(); } else animateCam(target);
  }
  function ensureVisible(n) {
    const b = bounds([n, ...CH.ghosts]);
    const c = CH.cam, sf = boardSafe(), bw = board.clientWidth, bh = board.clientHeight;
    const sx0 = b.x0 * c.k + c.x, sx1 = b.x1 * c.k + c.x, sy0 = b.y0 * c.k + c.y, sy1 = b.y1 * c.k + c.y;
    if (sx0 >= sf.left && sx1 <= bw - sf.right && sy0 >= sf.top && sy1 <= bh - sf.bottom) return;
    let dx = 0, dy = 0;
    if (sx1 > bw - sf.right) dx = bw - sf.right - sx1;
    if (sx0 + dx < sf.left) dx = sf.left - sx0;
    if (sy1 > bh - sf.bottom) dy = bh - sf.bottom - sy1;
    if (sy0 + dy < sf.top) dy = sf.top - sy0;
    animateCam({ k: c.k, x: c.x + dx, y: c.y + dy });
  }

  let bDrag = null;
  board.addEventListener('pointerdown', (e) => {
    if (e.target.closest('.node')) return;
    bDrag = { x: e.clientX, y: e.clientY, cx: CH.cam.x, cy: CH.cam.y, moved: false };
    board.setPointerCapture(e.pointerId);
    board.classList.add('dragging');
  });
  board.addEventListener('pointermove', (e) => {
    if (!bDrag) return;
    const dx = e.clientX - bDrag.x, dy = e.clientY - bDrag.y;
    if (Math.abs(dx) + Math.abs(dy) > 3) bDrag.moved = true;
    cancelAnimationFrame(boardAnim);
    CH.cam.x = bDrag.cx + dx; CH.cam.y = bDrag.cy + dy; applyBoardCam();
  });
  board.addEventListener('pointerup', () => {
    if (bDrag && !bDrag.moved && CH.active != null) setActive(null);
    bDrag = null; board.classList.remove('dragging');
  });
  board.addEventListener('wheel', (e) => {
    e.preventDefault();
    cancelAnimationFrame(boardAnim);
    const b = board.getBoundingClientRect();
    const mx = e.clientX - b.left, my = e.clientY - b.top;
    const c = CH.cam;
    const k = Math.max(0.2, Math.min(2.5, c.k * Math.exp(-e.deltaY * (e.ctrlKey ? 0.01 : 0.0015))));
    c.x = mx - (mx - c.x) * (k / c.k); c.y = my - (my - c.y) * (k / c.k); c.k = k;
    applyBoardCam();
  }, { passive: false });

  function bindNodeDrag(n) {
    let st = null;
    n.el.addEventListener('pointerdown', (e) => {
      if (e.target.closest('.del')) return;
      e.stopPropagation();
      st = { x: e.clientX, y: e.clientY, nx: n.x, ny: n.y, moved: false };
      n.el.setPointerCapture(e.pointerId);
    });
    n.el.addEventListener('pointermove', (e) => {
      if (!st) return;
      const dx = (e.clientX - st.x) / CH.cam.k, dy = (e.clientY - st.y) / CH.cam.k;
      if (!st.moved && Math.abs(dx) + Math.abs(dy) < 4) return;
      st.moved = true;
      n.x = st.nx + dx; n.y = st.ny + dy;
      n.el.style.left = n.x + 'px'; n.el.style.top = n.y + 'px';
      if (CH.active === n.id) {
        const cnt = CH.ghosts.length;
        CH.ghosts.forEach((g, k) => { g.x = n.x + GX; g.y = n.y + (k - (cnt - 1) / 2) * GY; g.el.style.left = g.x + 'px'; g.el.style.top = g.y + 'px'; });
      }
      renderLinks();
    });
    n.el.addEventListener('pointerup', () => {
      if (st && !st.moved && CH.active !== n.id) setActive(n);
      else if (st && st.moved) saveChain();
      st = null;
    });
    n.el.addEventListener('dblclick', () => select(n.i, true));
  }

  function tidy() {
    if (!CH.nodes.length) return;
    const kids = new Map(), hasParent = new Set();
    for (const l of CH.links) { if (!kids.has(l.a)) kids.set(l.a, []); kids.get(l.a).push(l.b); hasParent.add(l.b); }
    const roots = CH.nodes.filter((n) => !hasParent.has(n.id));
    const target = new Map();
    let nextY = 0;
    const place = (id, depth) => {
      const ch = kids.get(id) || [];
      let y;
      if (!ch.length) { y = nextY; nextY += GY; }
      else { const ys = ch.map((c) => place(c, depth + 1)); y = (ys[0] + ys[ys.length - 1]) / 2; }
      target.set(id, [depth * GX, y]);
      return y;
    };
    roots.forEach((r) => { place(r.id, 0); nextY += GY * 0.5; });
    const start = new Map(CH.nodes.map((n) => [n.id, [n.x, n.y]]));
    const t0 = performance.now();
    CH.ghosts.forEach((g) => g.el.remove()); CH.ghosts = [];
    let finished = false;
    const apply = (e) => {
      for (const n of CH.nodes) {
        const [sx, sy] = start.get(n.id), [tx, ty] = target.get(n.id);
        n.x = sx + (tx - sx) * e; n.y = sy + (ty - sy) * e;
        n.el.style.left = n.x + 'px'; n.el.style.top = n.y + 'px';
      }
      renderLinks();
    };
    const finish = () => { if (finished) return; finished = true; apply(1); rebuildGhosts(); renderLinks(); fitBoard(); saveChain(); };
    const step = (now) => {
      const t = Math.min(1, (now - t0) / 650);
      apply(ease(t));
      if (t < 1) requestAnimationFrame(step); else finish();
    };
    requestAnimationFrame(step);
    setTimeout(finish, 900);
  }

  function chainStartFrom(i) {
    const existing = CH.nodes.find((n) => n.i === i);
    if (existing) { setActive(existing); return; }
    let x = 0, y = 0;
    if (CH.nodes.length) { const b = bounds(CH.nodes); x = b.x0; y = b.y1 + GY * 0.6; }
    const n = addNode(i, null, x, y);
    setActive(n);
    setTimeout(() => fitBoard(), 30);
  }
  function chainRandom() {
    let pool = R.map((_, i) => i).filter((i) => base[i] && R[i].chr && R[i].cf > 0.35);
    if (!pool.length) pool = R.map((_, i) => i).filter((i) => base[i]);
    if (!pool.length) return;
    chainStartFrom(pool[Math.floor(Math.random() * pool.length)]);
  }
  function clearChain() {
    CH.nodes.forEach((n) => n.el.remove());
    CH.ghosts.forEach((g) => g.el.remove());
    CH.nodes = []; CH.links = []; CH.ghosts = []; CH.active = null;
    renderLinks(); renderChainTitle(); renderNextPanel(); saveChain();
  }
  const CHAIN_KEY = EMBED ? 'llmap-chain' : 'llv-chain';
  function saveChain() {
    // 記録 id（rid）で保存する: 資料庫が増減して並びが変わっても同じ写真を指す。
    store.set(CHAIN_KEY, { v: 2, nodes: CH.nodes.map(({ id, i, x, y }) => ({ id, rid: R[i].rid, x, y })), links: CH.links.map(({ a, b, rel }) => ({ a, b, rel })), active: CH.active, uid: CH.uid, rel: CH.rel });
  }
  function loadChain() {
    const s = store.get(CHAIN_KEY);
    if (!s || !Array.isArray(s.nodes)) return;
    CH.uid = s.uid || 1;
    CH.rel = s.rel || 'color';
    for (const n of s.nodes) {
      // 旧形式（並び番号 i）は資料庫が変わると別の写真を指すので読まない。
      const i = s.v === 2 ? IDX.get(n.rid) : (EMBED ? undefined : n.i);
      if (i != null && R[i] && !R[i].gone) { const m = { id: n.id, i, x: n.x, y: n.y }; CH.nodes.push(m); makeNodeEl(m); }
    }
    CH.links = (s.links || []).filter((l) => nodeById(l.a) && nodeById(l.b)).map((l) => ({ ...l, rel: l.rel || 'color' }));
    markRoots();
    const a = nodeById(s.active);
    if (a) setActive(a); else renderLinks();
  }
  $('t-random').onclick = chainRandom;
  $('chain-start').onclick = chainRandom;
  $('t-tidy').onclick = tidy;
  $('t-fit').onclick = () => fitBoard();
  $('t-clear').onclick = clearChain;

  // ================================================================ views / router
  function go(view, opts = {}) {
    if (view === 'about' || view === 'themes') {
      const target = view;
      go('landing');
      if (window.LLV_EMBED) { $('landing').scrollTop = 0; tellView(); return; }
      setTimeout(() => $(target).scrollIntoView({ behavior: 'smooth' }), 80);
      return;
    }
    const prev = S.view;
    if (prev === view) { if (view === 'chain' && opts.random && !CH.nodes.length) chainRandom(); return; }
    const swap = () => {
      S.view = view;
      document.body.dataset.view = view;
      document.querySelectorAll('.links a').forEach((a) => a.classList.toggle('on', a.dataset.go === view));
      $('landing').classList.remove('leaving');
      hideTip();
      if (view === 'landing') { closeDetail(); $('landing').scrollTop = 0; buildFloaters(); }
      if (view === 'explore') enterExplore();
      if (view === 'chain') {
        if (opts.random && !CH.nodes.length) chainRandom();
        renderNextPanel();
        requestAnimationFrame(() => fitBoard(true));
        setTimeout(() => fitBoard(true), 60);
      } else $('next').hidden = true;
      if (S.selected != null && !$('detail').hidden) renderDetail();
      writeHash();
      tellView();
    };
    if (prev === 'landing' && !window.LLV_EMBED) { $('landing').classList.add('leaving'); setTimeout(swap, 520); }
    else swap();
  }
  // 桌面に埋め込まれているとき: 画面の切替はサイドバーから（llmap:go）、今の画面を親へ知らせる。
  // 表紙（landing）は埋め込みでは主题区だけを出すので「themes」として扱う。
  function tellView() {
    if (!window.LLV_EMBED || window.parent === window) return;
    window.parent.postMessage({ type: 'llmap:view', view: S.view === 'landing' ? 'themes' : S.view }, '*');
  }
  // 記録の中身（言語・研究字段・状態）を差し替える（研究台で編集したとき）。色・配置はそのまま。
  function patchRecords(list) {
    for (const m of list || []) {
      const i = IDX.get(m.rid);
      if (i == null) continue;
      Object.assign(R[i], m);
      for (const d of DIMS) VAL[d.key][i] = d.get(R[i]);
      LK[i] = lkOf(R[i]); TK[i] = R[i].f.dis + '|' + R[i].f.car;
      const langs = [...R[i].main, ...R[i].aux].flatMap((c) => [I.lang.zh[c] || '', I.lang.ja[c] || '', (D.langs[c] && D.langs[c].name) || '', c]);
      const cols = [R[i].cn, ...R[i].pal.map((q) => q[5])].flatMap((c) => [c, I.cn.zh[c], I.cn.ja[c]]);
      const fv = Object.values(R[i].f).flatMap((v) => [v, I.values.ja[v] || '']);
      SEARCH[i] = [R[i].d, R[i].id, R[i].note, R[i].t, ...fv, ...langs, ...cols].join(' ').toLowerCase();
    }
    groupBy(LK, lkMap); groupBy(TK, tkMap);
    relCache.clear();
    for (const d of DIMS) {
      const c = new Map();
      VAL[d.key].forEach((vs) => vs.forEach((v) => c.set(v, (c.get(v) || 0) + 1)));
      let vals = [...c.keys()];
      if (d.order) vals = d.order.filter((v) => c.has(v));
      else if (d.sortByKey) vals.sort();
      else vals.sort((a, b) => c.get(b) - c.get(a));
      allValues[d.key] = vals;
    }
    tip.dataset.i = '';
    recompute({ keepCamera: true, keepTheme: true });
    if (S.view === 'chain') { CH.nodes.forEach((m) => { m.el.remove(); makeNodeEl(m); }); markRoots(); setActive(nodeById(CH.active)); }
  }
  // 詳情の「探索」区: 色板・色の情報・6 種の関連（全資料庫から。削除済みは除く）。
  function describe(rid) {
    const i = IDX.get(rid);
    if (i == null || R[i].gone) return null;
    const r = R[i];
    return {
      rid, pal: r.pal.map((q) => ({ hex: q[0], p: q[1], name: cnl(q[5]) })),
      rep: { hex: repHex(r), name: cnl(r.cn) }, cf: r.cf, L: r.L, chr: r.chr,
      // 研究台の範囲が資料庫の一部か（関連は全資料庫から探すので、範囲内の数も添える）。
      scoped: (() => { let n = 0; for (let k = 0; k < N; k++) n += base[k]; return n < N - countGone(); })(),
      relations: relations(i).map((rel) => ({
        key: rel.key, name: relName(rel.key), title: rel.title(), sub: rel.sub(),
        rids: [r.rid, ...rel.all.map((j) => R[j].rid)],
        inScope: rel.all.filter((j) => base[j]).map((j) => R[j].rid),
        items: rel.all.slice(0, 12).map((j) => ({ rid: R[j].rid, ph: R[j].ph, tag: rel.tag(j) })),
      })),
    };
  }
  function snapshot() {
    return {
      mode: S.mode, sort: S.sort, group: S.group, q: S.q, panel: S.panel,
      sel: Object.fromEntries(Object.entries(S.sel).map(([k, v]) => [k, [...v]])),
      range: { ...S.range }, pick: S.pick, rel: S.rel ? { rid: R[S.rel.i].rid, key: S.rel.key } : null,
      cam: { ...camTo },
    };
  }
  function restore(sn) {
    if (!sn) return;
    S.sel = Object.fromEntries(Object.entries(sn.sel || {}).map(([k, v]) => [k, new Set(v)]));
    S.range = sn.range || {}; S.pick = sn.pick || null; S.q = sn.q || ''; $('search').value = S.q;
    S.rel = sn.rel && IDX.has(sn.rel.rid) ? { i: IDX.get(sn.rel.rid), key: sn.rel.key } : null;
    if (sn.sort) { S.sort = sn.sort; $('sort').value = S.sort; }
    if (sn.group) { S.group = sn.group; groupSel.value = S.group; }
    S.mode = sn.mode || S.mode;
    S.panel = !!sn.panel; $('panel').hidden = !S.panel; document.body.classList.toggle('panel-open', S.panel);
    if (S.panel) renderCharts();
    recompute({ keepCamera: true });
    if (sn.cam && exploreReady) {
      // 配置が落ち着いたあとで、前のカメラ位置へ戻す。
      setTimeout(() => { Object.assign(camFrom, cam); Object.assign(camTo, sn.cam); camAnim = performance.now(); requestDraw(); }, 60);
    }
  }
  window.addEventListener('message', (e) => {
    if (e.source !== window.parent) return;
    const d = e.data || {};
    if (d.type === 'llmap:go' && ['explore', 'themes', 'chain'].includes(d.view)) go(d.view);
    else if (d.type === 'llmap:mode') {
      if (d.group && DIM[d.group]) { S.group = d.group; groupSel.value = d.group; }
      if (d.sort && sorters[d.sort]) { S.sort = d.sort; $('sort').value = d.sort; }
      if (d.mode) setMode(d.mode); else if (exploreReady) layout();
      writeHash(); tellState();
    } else if (d.type === 'llmap:scope') {
      // null = 全資料庫。それ以外は表示してよい記録 id。
      const allow = d.rids ? new Set(d.rids) : null;
      for (let i = 0; i < N; i++) base[i] = R[i].gone ? 0 : allow ? (allow.has(R[i].rid) ? 1 : 0) : 1;
      if (S.rel && !base[S.rel.i]) S.rel = null;
      if (S.panel) renderCharts();
      recompute({ keepTheme: true, keepCamera: !!d.keepCamera });
    } else if (d.type === 'llmap:selection') {
      checked = new Set((d.rids || []).map((rid) => IDX.get(rid)).filter((i) => i != null));
      requestDraw();
    } else if (d.type === 'llmap:focus') {
      const i = d.rid == null ? null : IDX.get(d.rid);
      if (i == null) { S.selected = null; } else { if (S.selected !== i) selT0 = performance.now(); S.selected = i; }
      requestDraw();
    } else if (d.type === 'llmap:patch') patchRecords(d.records);
    else if (d.type === 'llmap:panel') setPanel(!!d.open);
    else if (d.type === 'llmap:fit') { if (S.view === 'chain') fitBoard(); else { focusIdx = -1; labelsEl.dataset.k = ''; fitCamera(); tellState(); requestDraw(); } }
    else if (d.type === 'llmap:focusGroup') focusGroup(d.v == null ? -1 : groupBlocks.findIndex((g) => g.v === d.v));
    else if (d.type === 'llmap:clearCond') { if (d.id === '*') clearFilters(); else clearCondition(d.id); recompute({ keepTheme: true }); }
    else if (d.type === 'llmap:restore') restore(d.snap);
    else if (d.type === 'llmap:chainFrom') { const i = IDX.get(d.rid); if (i != null) { go('chain'); chainStartFrom(i); } }
    else if (d.type === 'llmap:lang' && I[d.lang]) setLang(d.lang);
    else if (d.type === 'llmap:req') {
      let data = null;
      if (d.what === 'describe') data = describe(d.rid);
      else if (d.what === 'active') { data = []; for (let i = 0; i < N; i++) if (active[i]) data.push(R[i].rid); }
      else if (d.what === 'snapshot') data = snapshot();
      post({ type: 'llmap:reply', reqId: d.reqId, data });
    }
  });
  document.querySelectorAll('[data-go]').forEach((el) => el.addEventListener('click', (e) => {
    e.preventDefault();
    go(el.dataset.go, { random: !!el.dataset.random });
  }));

  let hashLock = true;
  function writeHash() {
    if (hashLock) return;
    const p = new URLSearchParams();
    p.set('v', S.view);
    if (S.view === 'explore') {
      p.set('m', S.mode);
      if (S.mode === 'wall') p.set('s', S.sort);
      if (S.mode === 'group') p.set('g', S.group);
      const f = Object.entries(S.sel).filter(([, s]) => s.size).map(([k, s]) => k + ':' + [...s].join('|')).join(';');
      if (f) p.set('f', f);
      if (S.q) p.set('q', S.q);
      if (S.rel) p.set('rel', R[S.rel.i].id + ':' + S.rel.key);
    }
    if (S.selected != null) p.set('sel', R[S.selected].id);
    history.replaceState(null, '', S.view === 'landing' && S.selected == null ? location.pathname : '#' + p.toString());
  }
  function readHash() {
    const p = new URLSearchParams(location.hash.slice(1));
    if (p.get('m')) S.mode = p.get('m');
    if (p.get('s')) { S.sort = p.get('s'); $('sort').value = S.sort; }
    if (p.get('g') && DIM[p.get('g')]) { S.group = p.get('g'); groupSel.value = S.group; }
    if (p.get('q')) { S.q = p.get('q'); $('search').value = S.q; }
    if (p.get('f')) for (const part of p.get('f').split(';')) {
      const [k, v] = part.split(':');
      if (DIM[k] && v) S.sel[k] = new Set(v.split('|'));
    }
    if (p.get('rel')) {
      const [id, key] = p.get('rel').split(':');
      const i = R.findIndex((r) => r.id === id);
      if (i >= 0 && key) S.rel = { i, key };
    }
    // 桌面に埋め込まれているときは表紙を飛ばして探索から始める（主题は logo から）。
    return { view: p.get('v') || (window.LLV_EMBED ? 'explore' : 'landing'), sel: p.get('sel') };
  }

  // ================================================================ language
  function applyStatic() {
    document.documentElement.lang = LANG === 'ja' ? 'ja' : 'zh-CN';
    document.title = t('doc.title');
    document.querySelectorAll('[data-i18n]').forEach((el) => { el.textContent = t(el.dataset.i18n); });
    document.querySelectorAll('[data-i18n-html]').forEach((el) => { el.innerHTML = t(el.dataset.i18nHtml); });
    document.querySelectorAll('[data-i18n-ph]').forEach((el) => { el.placeholder = t(el.dataset.i18nPh); });
    document.querySelectorAll('[data-i18n-aria]').forEach((el) => { el.setAttribute('aria-label', t(el.dataset.i18nAria)); });
    document.querySelectorAll('#lang-sw button').forEach((b) => b.classList.toggle('on', b.dataset.l === LANG));
    const g = groupSel.value;
    groupSel.innerHTML = DIMS.map((d) => `<option value="${d.key}">${d.label}</option>`).join('');
    groupSel.value = g || S.group;
  }
  function setLang(l) {
    if (!I[l] || l === LANG) return;
    LANG = l;
    store.set('llv-lang', l);
    applyStatic();
    buildThemes();
    if (themeScrollUpdate) themeScrollUpdate();
    if (S.panel) renderCharts();
    renderChips();
    let n = 0; for (let i = 0; i < N; i++) n += active[i];
    renderHeading(n);
    labelsEl.dataset.k = ''; tip.dataset.i = '';
    requestDraw();
    if (!$('detail').hidden && S.selected != null) renderDetail();
    // chain nodes carry captions: rebuild them in the new language
    CH.nodes.forEach((m) => { m.el.remove(); makeNodeEl(m); });
    markRoots();
    setActive(nodeById(CH.active));
    renderChainTitle();
  }
  document.querySelectorAll('#lang-sw button').forEach((b) => (b.onclick = () => setLang(b.dataset.l)));

  // ================================================================ boot
  $('total').textContent = N.toLocaleString();
  applyStatic();
  const init = readHash();
  setMode(S.mode);
  buildThemes();
  themeScrollUpdate = setupThemeScroll();
  loadChain();
  renderChainTitle();
  recompute();
  hashLock = false;
  if (init.view === 'landing') { buildFloaters(); writeHash(); }
  else { S.view = 'boot'; go(init.view); }
  tellView();
  if (init.sel && !EMBED) { const i = R.findIndex((r) => r.id === init.sel); if (i >= 0) setTimeout(() => select(i, true), 100); }
  post({ type: 'llmap:ready', count: N });
  tellState();
})();
