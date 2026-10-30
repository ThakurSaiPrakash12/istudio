const express = require('express');
const { rateLimit } = require('express-rate-limit');
const { APP_NAME, CONTACT_EMAIL, LAST_UPDATED, privacy, terms } = require('../legal/legalContent');
const { createDataDeletionRequest } = require('../services/dataDeletionRequestService');
const { sendDeletionRequestNotification } = require('../services/emailService');
const path = require('path');
const fs = require('fs');
const logger = require('../config/logger');

const router = express.Router();

const appLogoPath = path.join(__dirname, '../assets/app_icon.png');
let appLogoBase64 = '';
try {
  if (fs.existsSync(appLogoPath)) {
    appLogoBase64 = `data:image/png;base64,${fs.readFileSync(appLogoPath).toString('base64')}`;
  }
} catch (err) {
  logger.warn('Could not read app logo file', { error: err.message });
}

router.get('/app-logo.png', (_req, res) => {
  if (fs.existsSync(appLogoPath)) {
    return res.type('image/png').sendFile(appLogoPath);
  }
  return res.status(404).end();
});

const escapeHtml = (value) =>
  String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');

const emailLink = `<a href="mailto:${CONTACT_EMAIL}">${escapeHtml(CONTACT_EMAIL)}</a>`;
const withEmail = (text) => escapeHtml(text).replace('{email}', emailLink);

function renderSection(section, index) {
  const body = section.body ? `<p>${withEmail(section.body)}</p>` : '';
  const points = section.points?.length
    ? `<ul>${section.points.map((p) => `<li>${withEmail(p)}</li>`).join('')}</ul>`
    : '';
  return `
    <section class="card">
      <h2><span class="num">${index + 1}</span>${escapeHtml(section.title)}</h2>
      ${body}${points}
    </section>`;
}

function renderPage(doc, otherDoc) {
  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${escapeHtml(doc.title)} - ${APP_NAME}</title>
  <style>
    :root { --ink: #0f172a; --body: #334155; --muted: #64748b; --accent: #4f46e5; --line: #e2e8f0; }
    * { box-sizing: border-box; }
    body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      line-height: 1.65; color: var(--body); background: #f8fafc; }
    main { max-width: 820px; margin: 0 auto; padding: 40px 20px 56px; }
    .brand { font-size: 13px; font-weight: 700; letter-spacing: 2px; text-transform: uppercase; color: var(--accent); }
    h1 { margin: 6px 0 4px; font-size: 34px; color: var(--ink); }
    .updated { color: var(--muted); font-size: 14px; margin: 0 0 18px; }
    .intro { font-size: 16px; margin: 0 0 28px; }
    .card { background: #fff; border: 1px solid var(--line); border-radius: 14px; padding: 20px 22px;
      margin-bottom: 14px; box-shadow: 0 1px 3px rgba(15, 23, 42, 0.04); }
    h2 { display: flex; align-items: center; gap: 10px; margin: 0 0 8px; font-size: 18px; color: var(--ink); }
    .num { display: inline-flex; align-items: center; justify-content: center; flex: none; width: 28px; height: 28px;
      border-radius: 50%; background: #eef2ff; color: var(--accent); font-size: 13px; font-weight: 800; }
    p { margin: 0; }
    ul { margin: 8px 0 0; padding-left: 22px; }
    li { margin-bottom: 6px; }
    a { color: var(--accent); }
    footer { margin-top: 28px; padding-top: 18px; border-top: 1px solid var(--line); font-size: 14px; color: var(--muted);
      display: flex; flex-wrap: wrap; justify-content: space-between; gap: 8px; }
  </style>
</head>
<body>
  <main>
    <div class="brand">${APP_NAME}</div>
    <h1>${escapeHtml(doc.title)}</h1>
    <p class="updated">Last updated ${LAST_UPDATED}</p>
    <p class="intro">${escapeHtml(doc.intro)}</p>
    ${doc.sections.map(renderSection).join('')}
    <footer>
      <span>&copy; ${new Date().getFullYear()} ${APP_NAME}. All rights reserved.</span>
      <a href="${otherDoc.path}">${escapeHtml(otherDoc.title)}</a>
    </footer>
  </main>
</body>
</html>`;
}

const pages = {
  privacy: { ...privacy, path: '/privacy-policy' },
  terms: { ...terms, path: '/terms-and-conditions' },
};
const privacyHtml = renderPage(pages.privacy, pages.terms);
const termsHtml = renderPage(pages.terms, pages.privacy);

/* ─────────────────────────────────────────────
   SUPPORT PAGE  (Knowledge Centre enhanced)
───────────────────────────────────────────── */
const { KB_CATEGORIES } = require('../legal/supportContent');

/* helpers */
function esc(s) { return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;'); }
// Build a flat list of {catId, catLabel, qi, q, a} for JSON embedding
const kbFlat = KB_CATEGORIES.flatMap(cat =>
  cat.faqs.map((item, qi) => ({
    catId:  cat.id,
    catLabel: cat.label,
    qi,
    q: item.q,
    a: item.a,  // may contain safe HTML like <strong> or <a>
  }))
);

function renderCategoryCards() {
  return KB_CATEGORIES.map((cat, i) => `
    <button class="kc-card" data-cat="${esc(cat.id)}" id="kc-card-${esc(cat.id)}" aria-pressed="false" type="button">
      <span class="kc-card-icon" aria-hidden="true">${cat.icon}</span>
      <span class="kc-card-body">
        <span class="kc-card-label">${esc(cat.label)}</span>
        <span class="kc-card-count">${cat.faqs.length} questions</span>
      </span>
      <span class="kc-card-arrow" aria-hidden="true">›</span>
    </button>`).join('');
}

function renderAccordionPanels() {
  return KB_CATEGORIES.map(cat => `
    <div class="kc-panel" id="kc-panel-${esc(cat.id)}" data-cat="${esc(cat.id)}" hidden>
      <div class="kc-panel-head">
        <span class="kc-panel-icon" aria-hidden="true">${cat.icon}</span>
        <div>
          <h3 class="kc-panel-title">${esc(cat.label)}</h3>
          <p class="kc-panel-desc">${esc(cat.desc)}</p>
        </div>
      </div>
      <div class="kc-acc-list">
        ${cat.faqs.map((item, qi) => `
        <div class="kc-acc-item" data-cat="${esc(cat.id)}" data-qi="${qi}">
          <button class="kc-acc-btn" aria-expanded="false" aria-controls="kc-ans-${esc(cat.id)}-${qi}" id="kc-q-${esc(cat.id)}-${qi}" type="button">
            <span class="kc-acc-q">${esc(item.q)}</span>
            <span class="kc-acc-chev" aria-hidden="true">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg>
            </span>
          </button>
          <div class="kc-acc-body" id="kc-ans-${esc(cat.id)}-${qi}" role="region" aria-labelledby="kc-q-${esc(cat.id)}-${qi}">
            <div class="kc-acc-inner"><p>${item.a}</p></div>
          </div>
        </div>`).join('')}
      </div>
    </div>`).join('');
}

const supportHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Support – ${APP_NAME}</title>
  <meta name="description" content="Get help with ${APP_NAME}. Browse FAQs, support categories, and contact our team at ${CONTACT_EMAIL}.">
  <link rel="icon" type="image/png" href="${appLogoBase64 || '/app-logo.png'}">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=Outfit:wght@600;700;800&family=Playfair+Display:wght@600;700&family=DM+Sans:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    /* ── Reset & App Color Tokens (Synced with mobile/lib/app/theme/app_colors.dart) ── */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      /* Obsidian Mist Canvas & Liquid Glass Surfaces */
      --canvas:         #070A12; /* Cosmic obsidian canvas (darkBg1) */
      --canvas-surface: #0B1020; /* Elevated surface (darkBg2) */
      --surface-card:   #111827; /* Deep card backdrop (darkSurface1) */
      --card-bg:        rgba(22, 28, 44, 0.78); /* Frosted liquid glass card (glassCardDark) */
      --card-border:    rgba(165, 180, 252, 0.16); /* Pastel periwinkle refractive rim (glassBorderDark) */
      --card-border-active: rgba(129, 140, 248, 0.55);

      /* Luminous Pastel Periwinkle & Neon Accents */
      --accent:         #818CF8; /* Luminous Pastel Periwinkle (sky - primary brand) */
      --accent-deep:    #6366F1; /* Radiant Iris Accent (skyDeep) */
      --accent-light:   #EEF2FF; /* Soft Periwinkle Tint (skyLight) */
      --accent-cyan:    #00E5FF; /* Electric Cyan (darkAccentCyan) */
      --accent-blue:    #38BDF8; /* Sky Blue (darkAccentBlue) */
      --accent-violet:  #8B5CF6; /* Iris Violet (darkAccentViolet) */
      --accent-tint:    rgba(129, 140, 248, 0.12); /* 20% Pastel Periwinkle Focus / Aura Ring */
      --mint:           #6EE7B7; /* Fresh Pastel Mint (pastelMint / receivedGreen) */

      /* App Signature Gradients */
      --cta-gradient:   linear-gradient(135deg, #00E5FF 0%, #38BDF8 30%, #6366F1 70%, #A855F7 100%);
      --sky-gradient:   linear-gradient(135deg, #818CF8 0%, #6366F1 100%);
      --glass-glow:     0 8px 32px rgba(99, 102, 241, 0.22);

      /* Typography & Text */
      --text-main:      #F5F7FF; /* Crisp Text (darkTextPrimary) */
      --text-secondary: #A7B1C8; /* Secondary Text (darkTextSecondary) */
      --text-muted:     #69748C; /* Muted Caption (darkTextMuted) */

      --radius:         16px;
      --ff-head:        'Outfit', 'Playfair Display', Georgia, sans-serif;
      --ff-body:        'Inter', 'DM Sans', -apple-system, system-ui, sans-serif;
    }
    html { scroll-behavior: smooth; }
    body {
      font-family: var(--ff-body);
      background: var(--canvas);
      color: var(--text-main);
      line-height: 1.65;
      min-height: 100vh;
    }

    /* ── Layout ── */
    .container { max-width: 1100px; margin: 0 auto; padding: 0 24px; }

    /* ── Navbar ── */
    #navbar {
      position: sticky; top: 0; z-index: 100;
      background: rgba(7, 10, 18, 0.88);
      backdrop-filter: blur(16px);
      -webkit-backdrop-filter: blur(16px);
      border-bottom: 1px solid var(--card-border);
    }
    .nav-inner {
      display: flex; align-items: center; justify-content: space-between;
      height: 68px; gap: 16px;
    }
    .nav-brand {
      font-family: var(--ff-head);
      font-size: 1.25rem;
      font-weight: 700;
      color: var(--text-main);
      text-decoration: none;
      display: flex; align-items: center; gap: 12px;
      flex-shrink: 0;
      letter-spacing: -0.01em;
    }
    .nav-logo {
      width: 38px; height: 38px; border-radius: 10px;
      object-fit: cover;
      box-shadow: 0 4px 14px rgba(129, 140, 248, 0.35);
      border: 1px solid rgba(165, 180, 252, 0.3);
      flex-shrink: 0;
      transition: transform .25s ease, box-shadow .25s ease;
    }
    .nav-brand:hover .nav-logo {
      transform: scale(1.06);
      box-shadow: 0 6px 20px rgba(129, 140, 248, 0.55);
    }
    .nav-brand-title {
      font-weight: 700;
      letter-spacing: -0.02em;
    }
    .nav-links {
      display: flex; align-items: center; gap: 6px;
      list-style: none; flex-wrap: wrap;
    }
    .nav-links a {
      color: var(--text-secondary);
      text-decoration: none;
      font-size: 0.9rem;
      font-weight: 500;
      padding: 7px 14px;
      border-radius: 9px;
      transition: color .2s, background .2s;
    }
    .nav-links a:hover, .nav-links a:focus {
      color: var(--text-main);
      background: var(--accent-tint);
      outline: none;
    }
    .nav-cta {
      background: var(--cta-gradient) !important;
      color: #070A12 !important;
      font-weight: 700 !important;
      padding: 9px 20px !important;
      border-radius: 10px !important;
      box-shadow: 0 4px 16px rgba(99, 102, 241, 0.35);
      transition: transform .18s, box-shadow .18s !important;
    }
    .nav-cta:hover {
      box-shadow: 0 6px 24px rgba(99, 102, 241, 0.55) !important;
      transform: translateY(-1px);
    }

    /* Hamburger */
    #menu-toggle { display: none; }
    .hamburger {
      display: none; flex-direction: column; justify-content: center; align-items: center;
      width: 40px; height: 40px; gap: 5px; cursor: pointer;
      background: none; border: none; padding: 4px;
    }
    .hamburger span {
      display: block; width: 22px; height: 2px;
      background: var(--text-main); border-radius: 2px;
      transition: transform .25s, opacity .25s;
    }
    #menu-toggle:checked ~ .nav-links { display: flex; flex-direction: column; align-items: flex-start; }

    /* ── Hero ── */
    #hero {
      padding: 96px 24px 80px;
      text-align: center;
      background:
        radial-gradient(ellipse 80% 60% at 50% -10%, rgba(129, 140, 248, 0.22) 0%, transparent 70%),
        radial-gradient(ellipse 60% 40% at 85% 15%, rgba(0, 229, 255, 0.12) 0%, transparent 60%),
        var(--canvas);
    }
    .hero-badge {
      display: inline-flex; align-items: center; gap: 8px;
      background: rgba(129, 140, 248, 0.12);
      border: 1px solid rgba(129, 140, 248, 0.32);
      border-radius: 999px;
      padding: 6px 16px;
      font-size: 0.8rem;
      font-weight: 600;
      color: var(--accent);
      letter-spacing: 0.06em;
      text-transform: uppercase;
      margin-bottom: 24px;
      box-shadow: 0 2px 12px rgba(129, 140, 248, 0.18);
    }
    .hero-badge::before { content: '⚡'; font-size: 0.9rem; }
    #hero h1 {
      font-family: var(--ff-head);
      font-size: clamp(2.4rem, 6vw, 3.8rem);
      line-height: 1.15;
      color: var(--text-main);
      margin-bottom: 20px;
      letter-spacing: -0.02em;
    }
    #hero h1 span {
      background: var(--cta-gradient);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
    }
    .hero-sub {
      max-width: 580px; margin: 0 auto 40px;
      font-size: 1.05rem;
      color: var(--text-secondary);
      line-height: 1.7;
    }
    .hero-actions { display: flex; gap: 14px; justify-content: center; flex-wrap: wrap; }
    .btn {
      display: inline-flex; align-items: center; gap: 8px;
      font-family: var(--ff-body); font-size: 0.95rem; font-weight: 600;
      padding: 13px 28px; border-radius: 10px;
      text-decoration: none; border: none; cursor: pointer;
      transition: transform .18s, box-shadow .18s, background .18s;
      white-space: nowrap;
    }
    .btn:hover { transform: translateY(-2px); }
    .btn-primary {
      background: var(--cta-gradient);
      color: #070A12;
      font-weight: 700;
      box-shadow: 0 4px 20px rgba(99, 102, 241, 0.35);
    }
    .btn-primary:hover {
      box-shadow: 0 6px 28px rgba(99, 102, 241, 0.55);
      transform: translateY(-2px);
    }
    .btn-ghost {
      background: rgba(255, 255, 255, 0.05);
      color: var(--text-main);
      border: 1px solid var(--card-border);
    }
    .btn-ghost:hover {
      background: var(--accent-tint);
      border-color: rgba(129, 140, 248, 0.4);
      transform: translateY(-2px);
    }

    /* ── Section common ── */
    section { padding: 80px 24px; }
    .section-label {
      font-size: 0.75rem; font-weight: 700;
      letter-spacing: 0.12em; text-transform: uppercase;
      color: var(--accent); margin-bottom: 12px;
    }
    .section-title {
      font-family: var(--ff-head);
      font-size: clamp(1.8rem, 4vw, 2.6rem);
      color: var(--text-main);
      margin-bottom: 14px;
      letter-spacing: -0.02em;
    }
    .section-sub {
      font-size: 1rem;
      color: var(--text-secondary);
      max-width: 540px;
      margin-bottom: 48px;
    }

    /* ── Support Categories ── */
    #categories { background: var(--canvas-surface); }
    .cats-grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
      gap: 18px;
      margin-top: 48px;
    }
    .cat-card {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: var(--radius);
      padding: 28px 22px;
      display: flex; flex-direction: column; gap: 12px;
      cursor: default;
      backdrop-filter: blur(12px);
      transition: transform .22s, border-color .22s, box-shadow .22s;
    }
    .cat-card:hover {
      transform: translateY(-4px);
      border-color: var(--card-border-active);
      box-shadow: var(--glass-glow);
    }
    .cat-icon {
      width: 48px; height: 48px;
      background: rgba(129, 140, 248, 0.12);
      border-radius: 12px;
      display: flex; align-items: center; justify-content: center;
      font-size: 1.4rem;
      color: var(--accent);
    }
    .cat-card h3 {
      font-size: 1rem; font-weight: 600;
      color: var(--text-main);
      line-height: 1.3;
    }
    .cat-card p {
      font-size: 0.85rem;
      color: var(--text-secondary);
      margin: 0;
    }

    /* ── Knowledge Centre ── */
    #knowledge-centre { background: var(--canvas); padding-bottom: 100px; }

    /* Search */
    .kc-search-wrap {
      max-width: 640px; margin: 0 auto 52px;
      position: relative;
    }
    .kc-search-wrap svg {
      position: absolute; left: 18px; top: 50%; transform: translateY(-50%);
      pointer-events: none; color: var(--text-secondary);
    }
    #kc-search {
      width: 100%; padding: 16px 20px 16px 52px;
      background: rgba(17, 24, 39, 0.85);
      border: 1px solid var(--card-border);
      border-radius: 12px;
      color: var(--text-main);
      font-family: var(--ff-body); font-size: 1rem;
      outline: none;
      transition: border-color .2s, box-shadow .2s;
    }
    #kc-search::placeholder { color: var(--text-muted); }
    #kc-search:focus {
      border-color: var(--accent);
      box-shadow: 0 0 0 3px rgba(129, 140, 248, 0.22);
    }
    .kc-clear-btn {
      position: absolute; right: 14px; top: 50%; transform: translateY(-50%);
      background: none; border: none; color: var(--text-secondary);
      cursor: pointer; padding: 4px; display: none; align-items: center;
      font-size: 1.2rem; line-height: 1;
    }
    .kc-clear-btn.visible { display: flex; }

    /* Category nav cards */
    .kc-cats { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 12px; margin-bottom: 44px; }
    .kc-card {
      display: flex; align-items: center; gap: 14px;
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 12px;
      padding: 16px 18px;
      cursor: pointer; text-align: left;
      transition: border-color .2s, background .2s, transform .18s;
      width: 100%;
    }
    .kc-card:hover {
      border-color: rgba(129, 140, 248, 0.45);
      background: rgba(129, 140, 248, 0.08);
      transform: translateY(-2px);
    }
    .kc-card[aria-pressed="true"] {
      border-color: var(--accent);
      background: rgba(129, 140, 248, 0.16);
      box-shadow: 0 4px 20px rgba(99, 102, 241, 0.25);
    }
    .kc-card:focus { outline: 2px solid var(--accent); outline-offset: 2px; }
    .kc-card-icon { font-size: 1.5rem; flex-shrink: 0; }
    .kc-card-body { flex: 1; min-width: 0; }
    .kc-card-label { display: block; font-size: 0.9rem; font-weight: 600; color: var(--text-main); line-height: 1.3; }
    .kc-card-count { display: block; font-size: 0.75rem; color: var(--text-secondary); margin-top: 2px; }
    .kc-card-arrow { font-size: 1.2rem; color: var(--text-secondary); flex-shrink: 0; transition: color .2s; }
    .kc-card[aria-pressed="true"] .kc-card-arrow { color: var(--accent); }

    /* Panels */
    .kc-panel-head {
      display: flex; align-items: flex-start; gap: 16px;
      margin-bottom: 28px; padding-bottom: 20px;
      border-bottom: 1px solid var(--card-border);
    }
    .kc-panel-icon { font-size: 2rem; flex-shrink: 0; margin-top: 2px; }
    .kc-panel-title { font-family: var(--ff-head); font-size: 1.4rem; color: var(--text-main); margin-bottom: 4px; }
    .kc-panel-desc { font-size: 0.9rem; color: var(--text-secondary); }

    /* Accordion items */
    .kc-acc-list { display: flex; flex-direction: column; gap: 8px; }
    .kc-acc-item {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: 12px; overflow: hidden;
      transition: border-color .2s;
    }
    .kc-acc-item:has(.kc-acc-btn[aria-expanded="true"]) { border-color: rgba(129, 140, 248, 0.45); }
    .kc-acc-btn {
      width: 100%; background: none; border: none;
      display: flex; align-items: center; justify-content: space-between; gap: 16px;
      padding: 20px 22px; cursor: pointer; text-align: left;
      color: var(--text-main); font-family: var(--ff-body); font-size: 0.95rem; font-weight: 600;
      transition: background .18s;
    }
    .kc-acc-btn:hover { background: rgba(129, 140, 248, 0.08); }
    .kc-acc-btn:focus { outline: 2px solid var(--accent); outline-offset: -2px; }
    .kc-acc-q { flex: 1; line-height: 1.45; }
    .kc-acc-chev {
      flex-shrink: 0; width: 28px; height: 28px;
      display: flex; align-items: center; justify-content: center;
      border-radius: 50%; background: rgba(129, 140, 248, 0.12);
      transition: transform .25s, background .2s;
    }
    .kc-acc-btn[aria-expanded="true"] .kc-acc-chev {
      transform: rotate(180deg); background: var(--accent);
    }
    .kc-acc-btn[aria-expanded="true"] .kc-acc-chev svg { stroke: #070A12; }
    .kc-acc-body { max-height: 0; overflow: hidden; transition: max-height .32s ease; }
    .kc-acc-body.open { /* height set by JS */ }
    .kc-acc-inner {
      padding: 4px 22px 22px;
      border-top: 1px solid var(--card-border);
    }
    .kc-acc-inner p { color: var(--text-secondary); font-size: 0.93rem; line-height: 1.75; }
    .kc-acc-inner a { color: var(--accent); }
    .kc-acc-inner strong { color: var(--text-main); font-weight: 600; }

    /* Search results view */
    #kc-search-results { display: none; }
    #kc-search-results.active { display: block; }
    .kc-sr-tag {
      display: inline-block; font-size: 0.72rem; font-weight: 700;
      letter-spacing: 0.06em; text-transform: uppercase;
      color: var(--accent); background: rgba(129, 140, 248, 0.12);
      border-radius: 6px; padding: 3px 9px; margin-bottom: 10px;
    }
    .kc-no-results {
      text-align: center; padding: 60px 20px;
      display: none;
    }
    .kc-no-results.visible { display: block; }
    .kc-no-results svg { color: var(--text-secondary); margin-bottom: 16px; }
    .kc-no-results p { color: var(--text-secondary); font-size: 0.95rem; margin-bottom: 20px; }
    .kc-no-results strong { color: var(--text-main); }

    /* Highlight match */
    mark { background: rgba(129, 140, 248, 0.35); color: #fff; border-radius: 3px; padding: 0 3px; }

    /* ── Contact ── */
    #contact { background: var(--canvas-surface); }
    .contact-card {
      max-width: 680px; margin: 0 auto;
      background: linear-gradient(135deg, rgba(129, 140, 248, 0.10) 0%, rgba(17, 24, 39, 0.92) 100%);
      border: 1px solid rgba(129, 140, 248, 0.28);
      border-radius: 20px;
      padding: 52px 48px;
      text-align: center;
      box-shadow: 0 16px 48px rgba(0, 0, 0, 0.45);
    }
    .contact-icon {
      font-size: 3rem; margin-bottom: 20px;
      display: block;
    }
    .contact-card h2 {
      font-family: var(--ff-head);
      font-size: 2rem;
      color: var(--text-main);
      margin-bottom: 12px;
      letter-spacing: -0.02em;
    }
    .contact-card .lead {
      color: var(--text-secondary); font-size: 1rem;
      margin-bottom: 32px; max-width: 460px; margin-left: auto; margin-right: auto;
    }
    .email-row {
      display: inline-flex; align-items: center; gap: 10px;
      background: rgba(7, 10, 18, 0.65);
      border: 1px solid rgba(129, 140, 248, 0.25);
      border-radius: 10px;
      padding: 12px 20px;
      margin-bottom: 28px;
      flex-wrap: wrap; justify-content: center;
    }
    .email-row a {
      color: var(--accent);
      font-weight: 600;
      text-decoration: none;
      font-size: 1rem;
    }
    .email-row a:hover { text-decoration: underline; }
    .copy-btn {
      background: rgba(129, 140, 248, 0.14);
      border: 1px solid rgba(129, 140, 248, 0.3);
      color: var(--accent);
      border-radius: 7px;
      padding: 5px 12px;
      font-size: 0.8rem;
      font-weight: 600;
      cursor: pointer;
      font-family: var(--ff-body);
      transition: background .18s;
    }
    .copy-btn:hover { background: rgba(129, 140, 248, 0.28); }
    .contact-actions { display: flex; gap: 14px; justify-content: center; flex-wrap: wrap; }
    .notice-box {
      margin-top: 32px;
      background: rgba(129, 140, 248, 0.08);
      border-left: 3px solid var(--accent);
      border-radius: 0 8px 8px 0;
      padding: 14px 18px;
      text-align: left;
      font-size: 0.875rem;
      color: var(--text-secondary);
    }
    .notice-box strong { color: var(--text-main); }

    /* ── Footer ── */
    #footer {
      background: var(--canvas);
      border-top: 1px solid var(--card-border);
      padding: 40px 24px;
    }
    .footer-inner {
      display: flex; flex-wrap: wrap;
      align-items: center; justify-content: space-between;
      gap: 16px;
    }
    .footer-brand {
      font-family: var(--ff-head);
      font-size: 1.1rem;
      color: var(--text-main);
      display: flex; align-items: center; gap: 10px;
      font-weight: 700;
    }
    .footer-logo {
      width: 28px; height: 28px; border-radius: 8px;
      object-fit: cover;
      box-shadow: 0 2px 8px rgba(129, 140, 248, 0.3);
    }
    .footer-links { display: flex; gap: 4px; flex-wrap: wrap; }
    .footer-links a {
      color: var(--text-secondary);
      font-size: 0.875rem;
      text-decoration: none;
      padding: 4px 10px;
      border-radius: 6px;
      transition: color .18s;
    }
    .footer-links a:hover { color: var(--accent); }
    .footer-copy {
      width: 100%;
      font-size: 0.8rem;
      color: var(--text-muted);
      margin-top: 8px;
    }

    /* ── Responsive ── */
    @media (max-width: 700px) {
      .hamburger { display: flex; }
      .nav-inner { position: relative; flex-wrap: wrap; height: auto; padding: 12px 0; }
      .nav-links {
        display: none;
        width: 100%; padding: 8px 0 16px;
        flex-direction: column; align-items: flex-start;
        border-top: 1px solid var(--card-border);
        margin-top: 8px;
      }
      .nav-links.open { display: flex; }
      .nav-links a { width: 100%; padding: 10px 4px; }
      #hero { padding: 72px 0 60px; }
      .contact-card { padding: 36px 24px; }
      .cats-grid { grid-template-columns: 1fr 1fr; }
    }
    @media (max-width: 460px) {
      .cats-grid { grid-template-columns: 1fr; }
    }

    /* ── Scroll-in animation ── */
    .reveal {
      opacity: 0;
      transform: translateY(22px);
      transition: opacity .55s ease, transform .55s ease;
    }
    .reveal.visible {
      opacity: 1;
      transform: translateY(0);
    }
  </style>
</head>
<body>

<!-- ════════════════ NAVBAR ════════════════ -->
<nav id="navbar" role="navigation" aria-label="Main navigation">
  <div class="container nav-inner">
    <a href="/support" class="nav-brand" aria-label="${APP_NAME} home">
      <img src="${appLogoBase64 || '/app-logo.png'}" alt="${APP_NAME} Logo" class="nav-logo" width="38" height="38">
      <span class="nav-brand-title">${APP_NAME}</span>
    </a>
    <button class="hamburger" id="hamburger-btn" aria-label="Toggle menu" aria-expanded="false" aria-controls="nav-menu">
      <span></span><span></span><span></span>
    </button>
    <ul class="nav-links" id="nav-menu" role="list">
      <li><a href="/support">Home</a></li>
      <li><a href="#faqs">FAQs</a></li>
      <li><a href="/privacy-policy">Privacy Policy</a></li>
      <li><a href="#contact" class="nav-cta">Contact Support</a></li>
    </ul>
  </div>
</nav>

<!-- ════════════════ HERO ════════════════ -->
<section id="hero" role="banner">
  <div class="container">
    <div class="hero-badge">Support Center</div>
    <h1>How Can We <span>Help You?</span></h1>
    <p class="hero-sub">Dedicated support for photographers and videographers using ${APP_NAME}. Find answers instantly or reach our team directly.</p>
    <div class="hero-actions">
      <a href="mailto:${CONTACT_EMAIL}?subject=Clients%20Hub%20Support%20Request" class="btn btn-primary" id="hero-email-btn">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="m2 7 10 7 10-7"/></svg>
        Email Support
      </a>
      <a href="#faqs" class="btn btn-ghost" id="hero-faqs-btn">
        <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><path d="M12 17h.01"/></svg>
        Explore FAQs
      </a>
    </div>
  </div>
</section>

<!-- ════════════════ KNOWLEDGE CENTRE ════════════════ -->
<section id="knowledge-centre" aria-labelledby="kc-heading">
  <div id="faqs" style="position:relative;top:-80px;visibility:hidden;"></div>
  <div class="container">
    <p class="section-label">Knowledge Centre</p>
    <h2 class="section-title" id="kc-heading">Find Your Answer</h2>
    <p class="section-sub">Browse by category or search across all ${KB_CATEGORIES.length} topics and ${kbFlat.length} questions.</p>

    <!-- Search -->
    <div class="kc-search-wrap">
      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/></svg>
      <input type="search" id="kc-search" placeholder="Search FAQs… e.g. invoice, payment, delete account" autocomplete="off" aria-label="Search FAQs" spellcheck="false">
      <button class="kc-clear-btn" id="kc-clear" aria-label="Clear search" type="button">✕</button>
    </div>

    <!-- No results -->
    <div class="kc-no-results" id="kc-no-results" role="status" aria-live="polite">
      <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5"><circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/><path d="M8 11h6"/></svg>
      <p><strong>No results found.</strong><br>Try different keywords, or browse a category below.</p>
      <a href="mailto:${CONTACT_EMAIL}?subject=Clients%20Hub%20Support%20Request" class="btn btn-primary" style="display:inline-flex;margin:0 auto">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="m2 7 10 7 10-7"/></svg>
        Email Support
      </a>
    </div>

    <!-- Search results panel -->
    <div id="kc-search-results" aria-live="polite"></div>

    <!-- Category nav cards -->
    <div class="kc-cats" id="kc-cats" role="list">
      ${renderCategoryCards()}
    </div>

    <!-- Per-category accordion panels -->
    <div id="kc-panels">
      ${renderAccordionPanels()}
    </div>
  </div>
</section>

<!-- ════════════════ CONTACT ════════════════ -->
<section id="contact" aria-labelledby="contact-heading">
  <div class="container">
    <div class="contact-card reveal">
      <span class="contact-icon" aria-hidden="true">✉️</span>
      <h2 id="contact-heading">Still Need Help?</h2>
      <p class="lead">Our support team is here for you. Email us and we'll get back to you as quickly as we can.</p>

      <div class="email-row">
        <a href="mailto:${CONTACT_EMAIL}?subject=Clients%20Hub%20Support%20Request" id="support-email-link">${CONTACT_EMAIL}</a>
        <button class="copy-btn" id="copy-email-btn" aria-label="Copy email address" type="button">Copy</button>
      </div>

      <div class="contact-actions">
        <a href="mailto:${CONTACT_EMAIL}?subject=Clients%20Hub%20Support%20Request" class="btn btn-primary" id="contact-email-btn">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" aria-hidden="true"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="m2 7 10 7 10-7"/></svg>
          Send Email
        </a>
        <a href="#knowledge-centre" class="btn btn-ghost" id="contact-faqs-btn">Browse FAQs</a>
      </div>

      <div class="notice-box" role="note">
        <strong>When reporting an issue, please include:</strong> your registered email, the device and OS version, a description of the issue, and steps to reproduce it.<br>
        <strong style="color:var(--accent)">Never share your password or OTP with anyone, including our support team.</strong>
      </div>
    </div>
  </div>
</section>

<!-- ════════════════ FOOTER ════════════════ -->
<footer id="footer" role="contentinfo">
  <div class="container footer-inner">
    <div class="footer-brand">
      <img src="${appLogoBase64 || '/app-logo.png'}" alt="${APP_NAME} Logo" class="footer-logo" width="28" height="28">
      <span>${APP_NAME}</span>
    </div>
    <nav class="footer-links" aria-label="Footer navigation">
      <a href="mailto:${CONTACT_EMAIL}?subject=Clients%20Hub%20Support%20Request">${CONTACT_EMAIL}</a>
      <a href="/privacy-policy">Privacy Policy</a>
      <a href="/delete-data">Delete Data</a>
    </nav>
    <p class="footer-copy">&copy; 2026 ${APP_NAME}. All rights reserved.</p>
  </div>
</footer>

<script>
  /* ── KB data (embedded from server) ── */
  var KB_DATA = ${JSON.stringify(kbFlat)};

  /* ─────────────────────────────────────────
     HAMBURGER
  ───────────────────────────────────────── */
  (function () {
    var btn = document.getElementById('hamburger-btn');
    var menu = document.getElementById('nav-menu');
    if (!btn || !menu) return;
    btn.addEventListener('click', function () {
      var open = menu.classList.toggle('open');
      btn.setAttribute('aria-expanded', String(open));
    });
  }());

  /* ─────────────────────────────────────────
     KNOWLEDGE CENTRE
  ───────────────────────────────────────── */
  (function () {
    var searchInput   = document.getElementById('kc-search');
    var clearBtn      = document.getElementById('kc-clear');
    var catsEl        = document.getElementById('kc-cats');
    var panelsEl      = document.getElementById('kc-panels');
    var srEl          = document.getElementById('kc-search-results');
    var noResultsEl   = document.getElementById('kc-no-results');
    var catCards      = Array.from(document.querySelectorAll('.kc-card'));
    var allPanels     = Array.from(document.querySelectorAll('.kc-panel'));
    var activePanel   = null;

    /* ── helpers ── */
    function stripHtml(html) {
      var d = document.createElement('div');
      d.innerHTML = html;
      return d.textContent || d.innerText || '';
    }

    function highlight(text, term) {
      if (!term) return text;
      var lower = text.toLowerCase();
      var lowerTerm = term.toLowerCase();
      var idx = lower.indexOf(lowerTerm);
      if (idx === -1) return text;
      var out = '';
      var start = 0;
      var termLen = term.length;
      while ((idx = lower.indexOf(lowerTerm, start)) !== -1) {
        out += text.slice(start, idx) + '<mark>' + text.slice(idx, idx + termLen) + '</mark>';
        start = idx + termLen;
      }
      out += text.slice(start);
      return out;
    }

    /* ── Accordion helpers ── */
    function closeAllAccInPanel(panel) {
      panel.querySelectorAll('.kc-acc-btn[aria-expanded="true"]').forEach(function (b) {
        closeAcc(b);
      });
    }

    function openAcc(btn) {
      var bodyId = btn.getAttribute('aria-controls');
      var body   = document.getElementById(bodyId);
      if (!body) return;
      btn.setAttribute('aria-expanded', 'true');
      body.style.maxHeight = body.scrollHeight + 'px';
      body.classList.add('open');
    }

    function closeAcc(btn) {
      var bodyId = btn.getAttribute('aria-controls');
      var body   = document.getElementById(bodyId);
      if (!body) return;
      btn.setAttribute('aria-expanded', 'false');
      body.style.maxHeight = '0';
      body.classList.remove('open');
    }

    function toggleAcc(btn) {
      if (btn.getAttribute('aria-expanded') === 'true') {
        closeAcc(btn);
      } else {
        /* Collapse siblings in same panel */
        var panel = btn.closest('.kc-panel, #kc-search-results');
        if (panel) {
          panel.querySelectorAll('.kc-acc-btn[aria-expanded="true"]').forEach(function (b) {
            if (b !== btn) closeAcc(b);
          });
        }
        openAcc(btn);
      }
    }

    /* Delegate accordion clicks for panels + search results */
    [panelsEl, srEl].forEach(function (root) {
      if (!root) return;
      root.addEventListener('click', function (e) {
        var btn = e.target.closest('.kc-acc-btn');
        if (btn) toggleAcc(btn);
      });
    });

    /* ── Category nav ── */
    function showPanel(catId) {
      allPanels.forEach(function (p) {
        if (p.dataset.cat === catId) {
          p.hidden = false;
          activePanel = p;
        } else {
          p.hidden = true;
        }
      });
      catCards.forEach(function (c) {
        var pressed = c.dataset.cat === catId;
        c.setAttribute('aria-pressed', String(pressed));
      });
      /* Show panels container, hide search results */
      panelsEl.style.display = '';
      srEl.classList.remove('active');
      noResultsEl.classList.remove('visible');
    }

    function hideAllPanels() {
      allPanels.forEach(function (p) { p.hidden = true; });
      catCards.forEach(function (c) { c.setAttribute('aria-pressed', 'false'); });
      activePanel = null;
    }

    catCards.forEach(function (card) {
      card.addEventListener('click', function () {
        var catId = card.dataset.cat;
        /* Toggle: clicking active card collapses it */
        if (card.getAttribute('aria-pressed') === 'true') {
          hideAllPanels();
          return;
        }
        searchInput.value = '';
        clearBtn.classList.remove('visible');
        srEl.classList.remove('active');
        noResultsEl.classList.remove('visible');
        showPanel(catId);
        /* Scroll panel into view on mobile */
        if (window.innerWidth < 700) {
          var panelEl = document.getElementById('kc-panel-' + catId);
          if (panelEl) { setTimeout(function () { panelEl.scrollIntoView({ behavior: 'smooth', block: 'start' }); }, 60); }
        }
      });
    });

    /* Open first category by default */
    if (catCards.length) showPanel(catCards[0].dataset.cat);

    /* ── Search ── */
    function doSearch(raw) {
      var term = raw.trim();
      clearBtn.classList.toggle('visible', term.length > 0);

      if (!term) {
        srEl.classList.remove('active');
        noResultsEl.classList.remove('visible');
        /* Restore last active panel */
        panelsEl.style.display = '';
        if (activePanel) activePanel.hidden = false;
        return;
      }

      /* Hide category panels while searching */
      allPanels.forEach(function (p) { p.hidden = true; });
      panelsEl.style.display = 'none';
      catCards.forEach(function (c) { c.setAttribute('aria-pressed', 'false'); });

      var lower = term.toLowerCase();
      var hits = KB_DATA.filter(function (item) {
        return item.q.toLowerCase().includes(lower) ||
               stripHtml(item.a).toLowerCase().includes(lower);
      });

      if (!hits.length) {
        srEl.innerHTML = '';
        srEl.classList.remove('active');
        noResultsEl.classList.add('visible');
        return;
      }

      noResultsEl.classList.remove('visible');

      /* Group hits by category */
      var groups = {};
      var order  = [];
      hits.forEach(function (item) {
        if (!groups[item.catId]) { groups[item.catId] = { label: item.catLabel, items: [] }; order.push(item.catId); }
        groups[item.catId].items.push(item);
      });

      var html = '<div class="kc-acc-list">';
      order.forEach(function (catId) {
        var group = groups[catId];
        group.items.forEach(function (item) {
          var bodyId = 'sr-ans-' + catId + '-' + item.qi;
          var qId    = 'sr-q-'   + catId + '-' + item.qi;
          html += '<div class="kc-acc-item" data-cat="' + catId + '">';
          html += '<div class="kc-sr-tag">' + group.label + '</div>';
          html += '<button class="kc-acc-btn" aria-expanded="false" aria-controls="' + bodyId + '" id="' + qId + '" type="button">';
          html += '<span class="kc-acc-q">' + highlight(item.q, term) + '</span>';
          html += '<span class="kc-acc-chev" aria-hidden="true"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg></span>';
          html += '</button>';
          html += '<div class="kc-acc-body" id="' + bodyId + '" role="region" aria-labelledby="' + qId + '">';
          html += '<div class="kc-acc-inner"><p>' + highlight(item.a, term) + '</p></div>';
          html += '</div></div>';
        });
      });
      html += '</div>';
      html += '<p style="margin-top:12px;font-size:0.82rem;color:var(--text-muted)">' + hits.length + ' result' + (hits.length === 1 ? '' : 's') + ' for &ldquo;' + term + '&rdquo; &nbsp;·&nbsp; <button type="button" onclick="document.getElementById(\'kc-search\').value=\'\';document.getElementById(\'kc-search\').dispatchEvent(new Event(\'input\'))" style="background:none;border:none;color:var(--teal);cursor:pointer;font-family:inherit;font-size:inherit;">Clear</button></p>';

      srEl.innerHTML = html;
      srEl.classList.add('active');
    }

    var debounceTimer;
    searchInput.addEventListener('input', function () {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(function () { doSearch(searchInput.value); }, 220);
    });

    clearBtn.addEventListener('click', function () {
      searchInput.value = '';
      doSearch('');
      searchInput.focus();
    });

    /* URL hash → open category */
    (function () {
      var hash = window.location.hash.replace('#kc-', '');
      if (hash) {
        var card = catCards.find(function (c) { return c.dataset.cat === hash; });
        if (card) { showPanel(hash); }
      }
    }());
  }());

  /* ─────────────────────────────────────────
     COPY EMAIL
  ───────────────────────────────────────── */
  (function () {
    var copyBtn = document.getElementById('copy-email-btn');
    if (!copyBtn) return;
    copyBtn.addEventListener('click', function () {
      navigator.clipboard.writeText('${CONTACT_EMAIL}').then(function () {
        copyBtn.textContent = 'Copied!';
        setTimeout(function () { copyBtn.textContent = 'Copy'; }, 2000);
      }).catch(function () {
        copyBtn.textContent = 'Failed';
        setTimeout(function () { copyBtn.textContent = 'Copy'; }, 2000);
      });
    });
  }());

  /* ─────────────────────────────────────────
     SCROLL REVEAL
  ───────────────────────────────────────── */
  (function () {
    if (!window.IntersectionObserver) {
      document.querySelectorAll('.reveal').forEach(function (el) { el.classList.add('visible'); });
      return;
    }
    var obs = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) { entry.target.classList.add('visible'); obs.unobserve(entry.target); }
      });
    }, { threshold: 0.06 });
    document.querySelectorAll('.reveal').forEach(function (el) { obs.observe(el); });
  }());
</script>
</body>
</html>`;

function renderDeleteDataPage({ submitted = false, error = '' } = {}) {
  const result = submitted
    ? `<section class="result" role="status"><h2>Request received</h2><p>If an account matches these details, we’ll verify ownership before processing deletion. We may contact you at the email provided if more information is needed.</p></section>`
    : '';
  const errorMessage = error
    ? `<p class="error" role="alert">${escapeHtml(error)}</p>`
    : '';
  const form = submitted
    ? ''
    : `<form method="post" action="/delete-data" novalidate>
        ${errorMessage}
        <label for="email">Account email</label>
        <input id="email" name="email" type="email" autocomplete="email" maxlength="254" required>
        <label for="phone">Account phone number</label>
        <input id="phone" name="phone" type="tel" inputmode="numeric" autocomplete="tel" maxlength="10" pattern="[0-9]{10}" placeholder="10-digit number" required>
        <div class="trap" aria-hidden="true"><label for="company">Leave this field empty</label><input id="company" name="company" tabindex="-1" autocomplete="off"></div>
        <button type="submit">Submit deletion request</button>
      </form>`;

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="robots" content="noindex, follow">
  <title>Request data deletion - ${APP_NAME}</title>
  <style>
    :root { color-scheme: light; --ink: #241a20; --body: #4c4147; --muted: #766a70; --accent: #88304e; --line: #e5dce0; --paper: #fff; --ground: #f8f4f5; }
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; background: radial-gradient(ellipse at 12% 0%, #f0e3e8 0, transparent 34rem), var(--ground); color: var(--body); font: 16px/1.55 system-ui, sans-serif; }
    main { width: min(100% - 32px, 620px); margin: 0 auto; padding: 48px 0 32px; }
    .brand { color: var(--accent); font-size: 13px; font-weight: 800; letter-spacing: 1.4px; text-transform: uppercase; }
    h1 { color: var(--ink); font: 700 34px/1.15 Georgia, serif; margin: 12px 0; }
    .intro { margin: 0 0 22px; }
    .panel { background: var(--paper); border: 1px solid var(--line); border-radius: 8px; padding: 24px; box-shadow: 0 12px 32px rgba(50, 20, 35, .06); }
    .notice { border-left: 3px solid var(--accent); padding: 10px 14px; background: #fbf6f8; font-size: 14px; margin-bottom: 22px; }
    label { display: block; color: var(--ink); font-size: 14px; font-weight: 700; margin: 16px 0 6px; }
    input { display: block; width: 100%; min-height: 48px; padding: 11px 12px; border: 1px solid #cfc2c8; border-radius: 5px; background: #fff; color: var(--ink); font: inherit; }
    input:focus { outline: 3px solid #88304e33; border-color: var(--accent); }
    button { display: inline-flex; justify-content: center; align-items: center; min-height: 48px; width: 100%; margin-top: 22px; padding: 10px 16px; border: 0; border-radius: 5px; background: var(--accent); color: #fff; font: inherit; font-weight: 700; cursor: pointer; }
    button:hover { background: #6f253f; }
    .error { color: #a12632; font-size: 14px; font-weight: 600; }
    .result h2 { margin: 0 0 8px; color: var(--ink); font-size: 20px; }
    .result p { margin: 0; }
    .trap { position: absolute; left: -10000px; width: 1px; height: 1px; overflow: hidden; }
    .help { margin: 18px 0 0; font-size: 14px; color: var(--muted); }
    a { color: var(--accent); }
    footer { display: flex; flex-wrap: wrap; gap: 8px 18px; border-top: 1px solid var(--line); margin-top: 28px; padding-top: 16px; font-size: 13px; }
    @media (max-width: 480px) { main { padding-top: 28px; } h1 { font-size: 29px; } .panel { padding: 19px; } }
  </style>
</head>
<body>
  <main>
    <div class="brand">${APP_NAME}</div>
    <h1>Request data deletion</h1>
    <p class="intro">Submit the email address and phone number linked to your account. We use them to locate your account and verify your request before deleting associated data.</p>
    <section class="panel">
      <div class="notice">Submitting this form does not immediately delete an account. If you can sign in, use Profile &gt; Account Settings &gt; Delete Account to complete deletion in the app.</div>
      ${result}${form}
    </section>
    <p class="help">Need help? Contact <a href="mailto:${CONTACT_EMAIL}">${escapeHtml(CONTACT_EMAIL)}</a>. Never send your password.</p>
    <footer><a href="/privacy-policy">Privacy policy</a><a href="/terms-and-conditions">Terms and conditions</a></footer>
  </main>
</body>
</html>`;
}

const deletionRequestLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: (_req, res) => res.status(429).type('html').send(renderDeleteDataPage({
    error: 'Too many requests. Please try again later.',
  })),
});

router.get(pages.privacy.path, (_req, res) => res.type('html').send(privacyHtml));
router.get(pages.terms.path, (_req, res) => res.type('html').send(termsHtml));
router.get('/terms', (_req, res) => res.redirect(301, pages.terms.path));
router.get('/delete-data', (_req, res) => res.type('html').send(renderDeleteDataPage()));
router.get('/support', (_req, res) => res.type('html').send(supportHtml));
router.post('/delete-data', deletionRequestLimiter, async (req, res) => {
  if (String(req.body?.company || '').trim()) {
    return res.type('html').send(renderDeleteDataPage({ submitted: true }));
  }

  const email = String(req.body?.email || '').trim().toLowerCase();
  const rawPhone = String(req.body?.phone || '').trim();
  const phoneDigits = rawPhone.replace(/\D/g, '');
  const phone =
    phoneDigits.length === 12 && phoneDigits.startsWith('91')
      ? phoneDigits.slice(2)
      : phoneDigits.length === 11 && phoneDigits.startsWith('0')
        ? phoneDigits.slice(1)
        : phoneDigits;

  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 254) {
    return res.status(400).type('html').send(renderDeleteDataPage({
      error: 'Enter a valid account email address.',
    }));
  }
  if (!/^\d{10}$/.test(phone)) {
    return res.status(400).type('html').send(renderDeleteDataPage({
      error: 'Enter the 10-digit phone number linked to your account.',
    }));
  }

  try {
    const request = await createDataDeletionRequest({ email, phone });
    const notification = await sendDeletionRequestNotification({
      requestId: request.id,
      email,
      phone,
      createdAt: request.createdAt,
    });
    if (!notification.sent) {
      logger.warn('Data deletion request saved without email notification', {
        requestId: request.id,
        reason: notification.reason,
      });
    }
    return res.type('html').send(renderDeleteDataPage({ submitted: true }));
  } catch (error) {
    logger.error('Unable to save data deletion request', { error });
    return res.status(503).type('html').send(renderDeleteDataPage({
      error: 'We could not save your request right now. Please try again or contact support.',
    }));
  }
});

module.exports = router;
