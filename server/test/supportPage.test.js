'use strict';

const assert = require('node:assert/strict');
const { describe, it } = require('node:test');
const request = require('supertest');

process.env.JWT_SECRET = 'test-secret-security-suite-32chars!!';
process.env.NODE_ENV = 'test';

const memoryUsers = require('../src/store/memoryUsers');
memoryUsers.enabled = true;
const { app } = require('../src/server');
const { KB_CATEGORIES } = require('../src/legal/supportContent');

describe('Clients Hub Support & FAQ Knowledge Centre Page', () => {
  it('serves the support page with 200 OK and text/html', async () => {
    const response = await request(app).get('/support');

    assert.equal(response.status, 200);
    assert.match(response.headers['content-type'], /text\/html/);
    assert.match(response.text, /Clients Hub/);
    assert.match(response.text, /istudio2512@gmail\.com/);
  });

  it('renders all 8 FAQ categories in the Knowledge Centre', async () => {
    const response = await request(app).get('/support');

    assert.equal(response.status, 200);
    assert.equal(KB_CATEGORIES.length, 8);

    const expectedCategories = [
      'About Clients Hub',
      'Events & Scheduling',
      'Client Management',
      'Payments & Expenses',
      'Invoices & Receipts',
      'Studio Profile & Photographer Discovery',
      'Settings & Personalisation',
      'Account & Privacy',
    ];

    for (const catName of expectedCategories) {
      assert.ok(
        response.text.includes(catName),
        `Support page should include category "${catName}"`
      );
    }
  });

  it('contains search bar, no results state, and contact support section', async () => {
    const response = await request(app).get('/support');

    assert.match(response.text, /id="kc-search"/);
    assert.match(response.text, /id="kc-no-results"/);
    assert.match(response.text, /id="contact"/);
    assert.match(response.text, /href="\/privacy-policy"/);
    assert.match(response.text, /href="\/delete-data"/);
  });

  it('includes embedded KB_DATA with questions and answers', async () => {
    const response = await request(app).get('/support');

    assert.match(response.text, /var KB_DATA = /);
    assert.match(response.text, /What is Clients Hub\?/);
    assert.match(response.text, /How do I create a new event\?/);
  });

  it('renders the app logo in the navbar and footer', async () => {
    const response = await request(app).get('/support');

    assert.match(response.text, /class="nav-logo"/);
    assert.match(response.text, /class="footer-logo"/);
  });

  it('serves the app logo via GET /app-logo.png', async () => {
    const response = await request(app).get('/app-logo.png');

    assert.equal(response.status, 200);
    assert.match(response.headers['content-type'], /image\/png/);
    assert.ok(response.body.length > 0);
  });

  it('applies the exact mobile app color scheme (pastel periwinkle and obsidian canvas)', async () => {
    const response = await request(app).get('/support');

    assert.match(response.text, /#070A12/); // Cosmic obsidian canvas (darkBg1)
    assert.match(response.text, /#818CF8/); // Luminous pastel periwinkle (sky - primary brand)
    assert.match(response.text, /#6366F1/); // Radiant iris accent (skyDeep)
    assert.match(response.text, /#6EE7B7/); // Pastel mint (pastelMint)
  });
});
