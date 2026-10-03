'use strict';

const assert = require('node:assert/strict');
const { test, afterEach } = require('node:test');

const emailService = require('../src/services/emailService');

const originalFetch = global.fetch;
const originalApiKey = process.env.BREVO_API_KEY;
const originalFromEmail = process.env.BREVO_FROM_EMAIL;
const originalFromName = process.env.BREVO_FROM_NAME;

afterEach(() => {
  global.fetch = originalFetch;
  if (originalApiKey === undefined) delete process.env.BREVO_API_KEY;
  else process.env.BREVO_API_KEY = originalApiKey;
  if (originalFromEmail === undefined) delete process.env.BREVO_FROM_EMAIL;
  else process.env.BREVO_FROM_EMAIL = originalFromEmail;
  if (originalFromName === undefined) delete process.env.BREVO_FROM_NAME;
  else process.env.BREVO_FROM_NAME = originalFromName;
});

test('sends verification email through Brevo over HTTPS when configured', async () => {
  process.env.BREVO_API_KEY = 'xkeysib-test-key';
  process.env.BREVO_FROM_EMAIL = 'verified@example.com';
  process.env.BREVO_FROM_NAME = 'Clients Hub';
  let request;
  global.fetch = async (url, options) => {
    request = { url, options };
    return {
      ok: true,
      status: 200,
      json: async () => ({ messageId: 'brevo-message-123' }),
    };
  };

  const result = await emailService.sendVerificationEmail({
    to: 'person@example.com',
    otp: '123456',
    username: 'Demo User',
  });

  assert.deepEqual(result, { sent: true, messageId: 'brevo-message-123' });
  assert.equal(request.url, 'https://api.brevo.com/v3/smtp/email');
  assert.equal(request.options.method, 'POST');
  assert.equal(request.options.headers['api-key'], 'xkeysib-test-key');
  const body = JSON.parse(request.options.body);
  assert.deepEqual(body.sender, {
    name: 'Clients Hub',
    email: 'verified@example.com',
  });
  assert.deepEqual(body.to, [{ email: 'person@example.com' }]);
  assert.match(body.textContent, /123456/);
  assert.match(body.htmlContent, /123456/);
});
