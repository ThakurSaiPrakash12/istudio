const express = require('express');
const { rateLimit } = require('express-rate-limit');
const { APP_NAME, CONTACT_EMAIL, LAST_UPDATED, privacy, terms } = require('../legal/legalContent');
const { createDataDeletionRequest } = require('../services/dataDeletionRequestService');
const { sendDeletionRequestNotification } = require('../services/emailService');
const logger = require('../config/logger');

const router = express.Router();

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
   SUPPORT PAGE
───────────────────────────────────────────── */
const supportHtml = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Support – ${APP_NAME}</title>
  <meta name="description" content="Get help with ${APP_NAME}. Browse FAQs, support categories, and contact our team at ${CONTACT_EMAIL}.">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@600;700&family=DM+Sans:wght@400;500;600&display=swap" rel="stylesheet">
  <style>
    /* ── Reset & Tokens ── */
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    :root {
      --navy:      #0B1320;
      --deep-navy: #1C2541;
      --slate:     #3A506B;
      --teal:      #5BC0BE;
      --teal-dark: #3a9e9c;
      --off-white: #F4F7F5;
      --text-muted:#8fa3b1;
      --card-bg:   rgba(255,255,255,0.04);
      --card-border:rgba(91,192,190,0.18);
      --shadow:    0 4px 32px rgba(0,0,0,0.28);
      --radius:    14px;
      --ff-head:   'Playfair Display', Georgia, serif;
      --ff-body:   'DM Sans', system-ui, sans-serif;
    }
    html { scroll-behavior: smooth; }
    body {
      font-family: var(--ff-body);
      background: var(--navy);
      color: var(--off-white);
      line-height: 1.65;
      min-height: 100vh;
    }

    /* ── Layout ── */
    .container { max-width: 1100px; margin: 0 auto; padding: 0 24px; }

    /* ── Navbar ── */
    #navbar {
      position: sticky; top: 0; z-index: 100;
      background: rgba(11,19,32,0.92);
      backdrop-filter: blur(14px);
      -webkit-backdrop-filter: blur(14px);
      border-bottom: 1px solid rgba(91,192,190,0.12);
    }
    .nav-inner {
      display: flex; align-items: center; justify-content: space-between;
      height: 64px; gap: 16px;
    }
    .nav-brand {
      font-family: var(--ff-head);
      font-size: 1.25rem;
      color: var(--off-white);
      text-decoration: none;
      display: flex; align-items: center; gap: 10px;
      flex-shrink: 0;
    }
    .nav-brand .logo-dot {
      width: 10px; height: 10px; border-radius: 50%;
      background: var(--teal);
      box-shadow: 0 0 8px var(--teal);
    }
    .nav-links {
      display: flex; align-items: center; gap: 4px;
      list-style: none; flex-wrap: wrap;
    }
    .nav-links a {
      color: rgba(244,247,245,0.75);
      text-decoration: none;
      font-size: 0.9rem;
      font-weight: 500;
      padding: 6px 12px;
      border-radius: 8px;
      transition: color .2s, background .2s;
    }
    .nav-links a:hover, .nav-links a:focus {
      color: var(--teal);
      background: rgba(91,192,190,0.1);
      outline: none;
    }
    .nav-cta {
      background: var(--teal) !important;
      color: var(--navy) !important;
      font-weight: 600 !important;
      padding: 8px 18px !important;
    }
    .nav-cta:hover { background: var(--teal-dark) !important; }

    /* Hamburger */
    #menu-toggle { display: none; }
    .hamburger {
      display: none; flex-direction: column; justify-content: center; align-items: center;
      width: 40px; height: 40px; gap: 5px; cursor: pointer;
      background: none; border: none; padding: 4px;
    }
    .hamburger span {
      display: block; width: 22px; height: 2px;
      background: var(--off-white); border-radius: 2px;
      transition: transform .25s, opacity .25s;
    }
    #menu-toggle:checked ~ .nav-links { display: flex; flex-direction: column; align-items: flex-start; }

    /* ── Hero ── */
    #hero {
      padding: 96px 24px 80px;
      text-align: center;
      background:
        radial-gradient(ellipse 80% 60% at 50% -10%, rgba(91,192,190,0.18) 0%, transparent 70%),
        var(--navy);
    }
    .hero-badge {
      display: inline-flex; align-items: center; gap: 8px;
      background: rgba(91,192,190,0.12);
      border: 1px solid rgba(91,192,190,0.3);
      border-radius: 999px;
      padding: 6px 16px;
      font-size: 0.8rem;
      font-weight: 600;
      color: var(--teal);
      letter-spacing: 0.06em;
      text-transform: uppercase;
      margin-bottom: 24px;
    }
    .hero-badge::before { content: '⚡'; font-size: 0.9rem; }
    #hero h1 {
      font-family: var(--ff-head);
      font-size: clamp(2.4rem, 6vw, 3.8rem);
      line-height: 1.15;
      color: var(--off-white);
      margin-bottom: 20px;
    }
    #hero h1 span { color: var(--teal); }
    .hero-sub {
      max-width: 560px; margin: 0 auto 40px;
      font-size: 1.05rem;
      color: var(--text-muted);
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
      background: var(--teal);
      color: var(--navy);
      box-shadow: 0 4px 20px rgba(91,192,190,0.35);
    }
    .btn-primary:hover { background: var(--teal-dark); box-shadow: 0 6px 28px rgba(91,192,190,0.5); }
    .btn-ghost {
      background: rgba(255,255,255,0.06);
      color: var(--off-white);
      border: 1px solid rgba(255,255,255,0.14);
    }
    .btn-ghost:hover { background: rgba(255,255,255,0.11); }

    /* ── Section common ── */
    section { padding: 80px 24px; }
    .section-label {
      font-size: 0.75rem; font-weight: 700;
      letter-spacing: 0.12em; text-transform: uppercase;
      color: var(--teal); margin-bottom: 12px;
    }
    .section-title {
      font-family: var(--ff-head);
      font-size: clamp(1.8rem, 4vw, 2.6rem);
      color: var(--off-white);
      margin-bottom: 14px;
    }
    .section-sub {
      font-size: 1rem;
      color: var(--text-muted);
      max-width: 520px;
      margin-bottom: 48px;
    }

    /* ── Support Categories ── */
    #categories { background: var(--deep-navy); }
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
      transition: transform .22s, border-color .22s, box-shadow .22s;
    }
    .cat-card:hover {
      transform: translateY(-4px);
      border-color: rgba(91,192,190,0.5);
      box-shadow: 0 8px 40px rgba(91,192,190,0.12);
    }
    .cat-icon {
      width: 48px; height: 48px;
      background: rgba(91,192,190,0.12);
      border-radius: 12px;
      display: flex; align-items: center; justify-content: center;
      font-size: 1.4rem;
    }
    .cat-card h3 {
      font-size: 1rem; font-weight: 600;
      color: var(--off-white);
      line-height: 1.3;
    }
    .cat-card p {
      font-size: 0.85rem;
      color: var(--text-muted);
      margin: 0;
    }

    /* ── FAQ ── */
    #faqs { background: var(--navy); }
    .faq-list { max-width: 760px; margin: 0 auto; display: flex; flex-direction: column; gap: 10px; }
    .faq-item {
      background: var(--card-bg);
      border: 1px solid var(--card-border);
      border-radius: var(--radius);
      overflow: hidden;
    }
    .faq-btn {
      width: 100%; background: none; border: none; padding: 22px 24px;
      display: flex; align-items: center; justify-content: space-between; gap: 16px;
      cursor: pointer; text-align: left;
      color: var(--off-white); font-family: var(--ff-body);
      font-size: 1rem; font-weight: 600;
      transition: background .18s;
    }
    .faq-btn:hover { background: rgba(91,192,190,0.07); }
    .faq-btn:focus { outline: 2px solid var(--teal); outline-offset: -2px; }
    .faq-chevron {
      flex-shrink: 0; width: 20px; height: 20px;
      display: flex; align-items: center; justify-content: center;
      border-radius: 50%;
      background: rgba(91,192,190,0.12);
      transition: transform .25s, background .2s;
    }
    .faq-chevron svg { display: block; }
    .faq-btn[aria-expanded="true"] .faq-chevron {
      transform: rotate(180deg);
      background: var(--teal);
    }
    .faq-btn[aria-expanded="true"] .faq-chevron svg path { stroke: var(--navy); }
    .faq-body {
      max-height: 0; overflow: hidden;
      transition: max-height .32s ease, padding .28s ease;
      padding: 0 24px;
    }
    .faq-body.open {
      padding: 0 24px 22px;
    }
    .faq-body p {
      color: var(--text-muted); font-size: 0.95rem; line-height: 1.7;
    }

    /* ── Contact ── */
    #contact { background: var(--deep-navy); }
    .contact-card {
      max-width: 680px; margin: 0 auto;
      background: linear-gradient(135deg, rgba(91,192,190,0.08) 0%, rgba(58,80,107,0.15) 100%);
      border: 1px solid rgba(91,192,190,0.22);
      border-radius: 20px;
      padding: 52px 48px;
      text-align: center;
    }
    .contact-icon {
      font-size: 3rem; margin-bottom: 20px;
      display: block;
    }
    .contact-card h2 {
      font-family: var(--ff-head);
      font-size: 2rem;
      color: var(--off-white);
      margin-bottom: 12px;
    }
    .contact-card .lead {
      color: var(--text-muted); font-size: 1rem;
      margin-bottom: 32px; max-width: 460px; margin-left: auto; margin-right: auto;
    }
    .email-row {
      display: inline-flex; align-items: center; gap: 10px;
      background: rgba(0,0,0,0.25);
      border: 1px solid rgba(91,192,190,0.2);
      border-radius: 10px;
      padding: 12px 20px;
      margin-bottom: 28px;
      flex-wrap: wrap; justify-content: center;
    }
    .email-row a {
      color: var(--teal);
      font-weight: 600;
      text-decoration: none;
      font-size: 1rem;
    }
    .email-row a:hover { text-decoration: underline; }
    .copy-btn {
      background: rgba(91,192,190,0.12);
      border: 1px solid rgba(91,192,190,0.25);
      color: var(--teal);
      border-radius: 7px;
      padding: 5px 12px;
      font-size: 0.8rem;
      font-weight: 600;
      cursor: pointer;
      font-family: var(--ff-body);
      transition: background .18s;
    }
    .copy-btn:hover { background: rgba(91,192,190,0.22); }
    .contact-actions { display: flex; gap: 14px; justify-content: center; flex-wrap: wrap; }
    .notice-box {
      margin-top: 32px;
      background: rgba(91,192,190,0.07);
      border-left: 3px solid var(--teal);
      border-radius: 0 8px 8px 0;
      padding: 14px 18px;
      text-align: left;
      font-size: 0.875rem;
      color: var(--text-muted);
    }
    .notice-box strong { color: var(--off-white); }

    /* ── Footer ── */
    #footer {
      background: var(--navy);
      border-top: 1px solid rgba(91,192,190,0.1);
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
      color: var(--off-white);
      display: flex; align-items: center; gap: 8px;
    }
    .footer-brand .dot {
      width: 8px; height: 8px; border-radius: 50%;
      background: var(--teal);
    }
    .footer-links { display: flex; gap: 4px; flex-wrap: wrap; }
    .footer-links a {
      color: var(--text-muted);
      font-size: 0.875rem;
      text-decoration: none;
      padding: 4px 10px;
      border-radius: 6px;
      transition: color .18s;
    }
    .footer-links a:hover { color: var(--teal); }
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
        border-top: 1px solid rgba(91,192,190,0.1);
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
      <span class="logo-dot" aria-hidden="true"></span>
      ${APP_NAME}
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

<!-- ════════════════ CATEGORIES ════════════════ -->
<section id="categories" aria-labelledby="cats-heading">
  <div class="container">
    <p class="section-label">Browse by topic</p>
    <h2 class="section-title" id="cats-heading">Support Categories</h2>
    <p class="section-sub">Find help for the specific area you need.</p>
    <div class="cats-grid" role="list">

      <article class="cat-card reveal" role="listitem">
        <div class="cat-icon" aria-hidden="true">👤</div>
        <h3>Account &amp; Login</h3>
        <p>Sign-up, Google sign-in, email verification, password reset, and account deletion.</p>
      </article>

      <article class="cat-card reveal" role="listitem">
        <div class="cat-icon" aria-hidden="true">📅</div>
        <h3>Events &amp; Scheduling</h3>
        <p>Creating, editing, and managing shoots, events, and deliverable timelines.</p>
      </article>

      <article class="cat-card reveal" role="listitem">
        <div class="cat-icon" aria-hidden="true">🤝</div>
        <h3>Client Management</h3>
        <p>Adding clients, storing contact details, and linking clients to events.</p>
      </article>

      <article class="cat-card reveal" role="listitem">
        <div class="cat-icon" aria-hidden="true">💳</div>
        <h3>Payments &amp; Expenses</h3>
        <p>Recording payments, uploading payment proofs, tracking expenses per event.</p>
      </article>

      <article class="cat-card reveal" role="listitem">
        <div class="cat-icon" aria-hidden="true">🧾</div>
        <h3>Invoices &amp; Receipts</h3>
        <p>Generating, sharing, marking paid or partial, and managing invoice due dates.</p>
      </article>

      <article class="cat-card reveal" role="listitem">
        <div class="cat-icon" aria-hidden="true">🏢</div>
        <h3>Studio Profile</h3>
        <p>Updating studio name, logo, address, UPI ID, QR code, and social links.</p>
      </article>

      <article class="cat-card reveal" role="listitem">
        <div class="cat-icon" aria-hidden="true">🔔</div>
        <h3>Notifications</h3>
        <p>Reminders for upcoming shoots and event-related alerts.</p>
      </article>

      <article class="cat-card reveal" role="listitem">
        <div class="cat-icon" aria-hidden="true">🛠️</div>
        <h3>Technical Issues</h3>
        <p>App errors, crashes, or anything not working as expected.</p>
      </article>

    </div>
  </div>
</section>

<!-- ════════════════ FAQ ════════════════ -->
<section id="faqs" aria-labelledby="faqs-heading">
  <div class="container">
    <p class="section-label">Quick answers</p>
    <h2 class="section-title" id="faqs-heading">Frequently Asked Questions</h2>
    <p class="section-sub">Answers about features available in the current version of ${APP_NAME}.</p>

    <div class="faq-list" role="list">

      <div class="faq-item reveal" role="listitem">
        <button class="faq-btn" aria-expanded="false" aria-controls="faq-1" id="faq-btn-1">
          How do I create a new event or shoot?
          <span class="faq-chevron" aria-hidden="true"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg></span>
        </button>
        <div class="faq-body" id="faq-1" role="region" aria-labelledby="faq-btn-1">
          <p>Tap the <strong>Events</strong> tab in the bottom navigation, then tap the <strong>+</strong> button. Fill in the event name, date, type, and any notes, then save. You can link a client and add deliverables, payments, and expenses to the event afterwards.</p>
        </div>
      </div>

      <div class="faq-item reveal" role="listitem">
        <button class="faq-btn" aria-expanded="false" aria-controls="faq-2" id="faq-btn-2">
          How do I add a client to ${APP_NAME}?
          <span class="faq-chevron" aria-hidden="true"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg></span>
        </button>
        <div class="faq-body" id="faq-2" role="region" aria-labelledby="faq-btn-2">
          <p>Go to the <strong>Clients</strong> tab and tap <strong>+</strong>. Enter the client's name, phone number, address, and any other details. Once saved, you can associate this client with events and generate invoices for them.</p>
        </div>
      </div>

      <div class="faq-item reveal" role="listitem">
        <button class="faq-btn" aria-expanded="false" aria-controls="faq-3" id="faq-btn-3">
          How do I record a payment for an event?
          <span class="faq-chevron" aria-hidden="true"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg></span>
        </button>
        <div class="faq-body" id="faq-3" role="region" aria-labelledby="faq-btn-3">
          <p>Open the event, go to the <strong>Payments</strong> tab within that event, and tap <strong>Add Payment</strong>. Enter the amount, payment mode (UPI, cash, bank transfer, etc.), and optionally upload a payment proof screenshot. ${APP_NAME} does not process payments itself — it is a record-keeping tool.</p>
        </div>
      </div>

      <div class="faq-item reveal" role="listitem">
        <button class="faq-btn" aria-expanded="false" aria-controls="faq-4" id="faq-btn-4">
          How do I track expenses for a shoot?
          <span class="faq-chevron" aria-hidden="true"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg></span>
        </button>
        <div class="faq-body" id="faq-4" role="region" aria-labelledby="faq-btn-4">
          <p>Open the event and navigate to the <strong>Expenses</strong> tab. Tap <strong>Add Expense</strong>, enter a description and amount, and save. All expenses are linked to that event and visible in your event summary.</p>
        </div>
      </div>

      <div class="faq-item reveal" role="listitem">
        <button class="faq-btn" aria-expanded="false" aria-controls="faq-5" id="faq-btn-5">
          How do I create and share an invoice?
          <span class="faq-chevron" aria-hidden="true"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg></span>
        </button>
        <div class="faq-body" id="faq-5" role="region" aria-labelledby="faq-btn-5">
          <p>Go to the <strong>Invoices</strong> section and tap <strong>Create Invoice</strong>. Select the client, add line items with amounts, set the due date, and save. You can then mark the invoice as paid, partially paid, or extend the due date. Invoices include your studio branding and can be shared directly from the app.</p>
        </div>
      </div>

      <div class="faq-item reveal" role="listitem">
        <button class="faq-btn" aria-expanded="false" aria-controls="faq-6" id="faq-btn-6">
          How do I update my studio profile and logo?
          <span class="faq-chevron" aria-hidden="true"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg></span>
        </button>
        <div class="faq-body" id="faq-6" role="region" aria-labelledby="faq-btn-6">
          <p>Go to <strong>Profile</strong> &gt; <strong>Edit Profile</strong>. You can update your studio name, owner name, address, city, specialties, social links, UPI ID, and payment QR code. To change your logo, tap the logo area and select a new image from your device. All uploads are stored securely.</p>
        </div>
      </div>

      <div class="faq-item reveal" role="listitem">
        <button class="faq-btn" aria-expanded="false" aria-controls="faq-7" id="faq-btn-7">
          Can I change the theme or appearance of the app?
          <span class="faq-chevron" aria-hidden="true"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg></span>
        </button>
        <div class="faq-body" id="faq-7" role="region" aria-labelledby="faq-btn-7">
          <p>Theme customisation is not available in the current version of ${APP_NAME}. If you would like to see this feature, please send your feedback to <a href="mailto:${CONTACT_EMAIL}">support</a>.</p>
        </div>
      </div>

      <div class="faq-item reveal" role="listitem">
        <button class="faq-btn" aria-expanded="false" aria-controls="faq-8" id="faq-btn-8">
          How do I delete my account?
          <span class="faq-chevron" aria-hidden="true"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg></span>
        </button>
        <div class="faq-body" id="faq-8" role="region" aria-labelledby="faq-btn-8">
          <p>Go to <strong>Profile</strong> &gt; <strong>Account Settings</strong> &gt; <strong>Delete Account</strong>. This permanently removes your account and studio data from our active systems. If you are unable to sign in, you can submit a data deletion request at <a href="/delete-data">/delete-data</a>. Backup copies are cleared within a reasonable period after deletion.</p>
        </div>
      </div>

      <div class="faq-item reveal" role="listitem">
        <button class="faq-btn" aria-expanded="false" aria-controls="faq-9" id="faq-btn-9">
          I forgot my password. How do I reset it?
          <span class="faq-chevron" aria-hidden="true"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg></span>
        </button>
        <div class="faq-body" id="faq-9" role="region" aria-labelledby="faq-btn-9">
          <p>On the login screen, tap <strong>Forgot Password?</strong>. Enter your registered email address and we'll send you a password reset link. Check your spam/junk folder if you don't see it within a few minutes. ${APP_NAME} support will never ask for your password or OTP.</p>
        </div>
      </div>

      <div class="faq-item reveal" role="listitem">
        <button class="faq-btn" aria-expanded="false" aria-controls="faq-10" id="faq-btn-10">
          How do I view my monthly financial summary?
          <span class="faq-chevron" aria-hidden="true"><svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5"><path d="m6 9 6 6 6-6"/></svg></span>
        </button>
        <div class="faq-body" id="faq-10" role="region" aria-labelledby="faq-btn-10">
          <p>Navigate to the <strong>Reports</strong> or <strong>Summary</strong> section of the app. Monthly summaries are generated automatically based on your recorded events, payments, and expenses, giving you an overview of your studio's financial activity for each month.</p>
        </div>
      </div>

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
        <a href="#faqs" class="btn btn-ghost" id="contact-faqs-btn">Browse FAQs</a>
      </div>

      <div class="notice-box" role="note">
        <strong>When reporting an issue, please include:</strong> your registered email, the device and OS version, a description of the issue, and steps to reproduce it.<br>
        <strong style="color:var(--teal)">Never share your password or OTP with anyone, including our support team.</strong>
      </div>
    </div>
  </div>
</section>

<!-- ════════════════ FOOTER ════════════════ -->
<footer id="footer" role="contentinfo">
  <div class="container footer-inner">
    <div class="footer-brand">
      <span class="dot" aria-hidden="true"></span>
      ${APP_NAME}
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
  /* ── Hamburger menu ── */
  (function () {
    var btn = document.getElementById('hamburger-btn');
    var menu = document.getElementById('nav-menu');
    if (!btn || !menu) return;
    btn.addEventListener('click', function () {
      var open = menu.classList.toggle('open');
      btn.setAttribute('aria-expanded', String(open));
    });
  }());

  /* ── FAQ accordion ── */
  (function () {
    var items = document.querySelectorAll('.faq-btn');
    items.forEach(function (btn) {
      btn.addEventListener('click', function () {
        var expanded = btn.getAttribute('aria-expanded') === 'true';
        var bodyId = btn.getAttribute('aria-controls');
        var body = document.getElementById(bodyId);
        if (!body) return;

        // Collapse all others
        items.forEach(function (other) {
          if (other === btn) return;
          var otherId = other.getAttribute('aria-controls');
          var otherBody = document.getElementById(otherId);
          other.setAttribute('aria-expanded', 'false');
          if (otherBody) { otherBody.style.maxHeight = '0'; otherBody.classList.remove('open'); }
        });

        if (expanded) {
          btn.setAttribute('aria-expanded', 'false');
          body.style.maxHeight = '0';
          body.classList.remove('open');
        } else {
          btn.setAttribute('aria-expanded', 'true');
          body.classList.add('open');
          body.style.maxHeight = body.scrollHeight + 'px';
        }
      });
    });
  }());

  /* ── Copy email ── */
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

  /* ── Scroll reveal ── */
  (function () {
    if (!window.IntersectionObserver) {
      document.querySelectorAll('.reveal').forEach(function (el) { el.classList.add('visible'); });
      return;
    }
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          entry.target.classList.add('visible');
          observer.unobserve(entry.target);
        }
      });
    }, { threshold: 0.08 });
    document.querySelectorAll('.reveal').forEach(function (el) { observer.observe(el); });
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
