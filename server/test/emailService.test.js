'use strict';

const assert = require('node:assert/strict');
const { test, afterEach } = require('node:test');
const { google } = require('googleapis');

const emailService = require('../src/services/emailService');

const originalGmail = google.gmail;
const originalClientId = process.env.GOOGLE_CLIENT_ID;
const originalClientSecret = process.env.GOOGLE_CLIENT_SECRET;
const originalRefreshToken = process.env.GMAIL_REFRESH_TOKEN;
const originalUser = process.env.GMAIL_USER;
const originalFrom = process.env.EMAIL_FROM;

afterEach(() => {
  google.gmail = originalGmail;
  for (const [key, value] of [
    ['GOOGLE_CLIENT_ID', originalClientId],
    ['GOOGLE_CLIENT_SECRET', originalClientSecret],
    ['GMAIL_REFRESH_TOKEN', originalRefreshToken],
    ['GMAIL_USER', originalUser],
    ['EMAIL_FROM', originalFrom],
  ]) {
    if (value === undefined) delete process.env[key];
    else process.env[key] = value;
  }
});

test('sends verification email through Gmail API when OAuth is configured', async () => {
  process.env.GOOGLE_CLIENT_ID = 'client-id';
  process.env.GOOGLE_CLIENT_SECRET = 'client-secret';
  process.env.GMAIL_REFRESH_TOKEN = 'refresh-token';
  process.env.GMAIL_USER = 'sender@gmail.com';
  process.env.EMAIL_FROM = 'Clients Hub <sender@gmail.com>';

  let request;
  google.gmail = () => ({
    users: {
      messages: {
        send: async (options) => {
          request = options;
          return { data: { id: 'gmail-message-123' } };
        },
      },
    },
  });

  const result = await emailService.sendVerificationEmail({
    to: 'person@example.com',
    otp: '123456',
    username: 'Demo User',
  });

  assert.deepEqual(result, { sent: true, messageId: 'gmail-message-123' });
  assert.equal(request.userId, 'me');
  assert.equal(typeof request.requestBody.raw, 'string');
  const mime = Buffer.from(request.requestBody.raw, 'base64url').toString('utf8');
  assert.match(mime, /From: Clients Hub <sender@gmail.com>/);
  assert.match(mime, /To: person@example.com/);
  assert.match(mime, /123456/);
  assert.match(mime, /Demo User/);
});
