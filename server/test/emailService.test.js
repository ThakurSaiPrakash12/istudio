'use strict';

const assert = require('node:assert/strict');
const { test, afterEach } = require('node:test');

const emailService = require('../src/services/emailService');

const originalFetch = global.fetch;
const originalApiKey = process.env.RESEND_API_KEY;
const originalFrom = process.env.RESEND_FROM;

afterEach(() => {
  global.fetch = originalFetch;
  if (originalApiKey === undefined) delete process.env.RESEND_API_KEY;
  else process.env.RESEND_API_KEY = originalApiKey;
  if (originalFrom === undefined) delete process.env.RESEND_FROM;
  else process.env.RESEND_FROM = originalFrom;
});

test('sends verification email through Resend over HTTPS when configured', async () => {
  process.env.RESEND_API_KEY = 're_test_key';
  process.env.RESEND_FROM = 'Clients Hub <verified@example.com>';
  let request;
  global.fetch = async (url, options) => {
    request = { url, options };
    return {
      ok: true,
      status: 200,
      json: async () => ({ id: 'resend-message-123' }),
    };
  };

  const result = await emailService.sendVerificationEmail({
    to: 'person@example.com',
    otp: '123456',
    username: 'Demo User',
  });

  assert.deepEqual(result, { sent: true, messageId: 'resend-message-123' });
  assert.equal(request.url, 'https://api.resend.com/emails');
  assert.equal(request.options.method, 'POST');
  assert.equal(request.options.headers.Authorization, 'Bearer re_test_key');
  const body = JSON.parse(request.options.body);
  assert.deepEqual(body.to, ['person@example.com']);
  assert.equal(body.from, 'Clients Hub <verified@example.com>');
  assert.match(body.text, /123456/);
  assert.match(body.html, /123456/);
});
