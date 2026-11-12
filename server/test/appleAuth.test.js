'use strict';

const assert = require('node:assert/strict');
const { describe, it, before, after } = require('node:test');
const request = require('supertest');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'test-secret-security-suite-32chars!!';
process.env.NODE_ENV = 'test';

const memoryUsers = require('../src/store/memoryUsers');
memoryUsers.enabled = true;

const appleAuthService = require('../src/services/appleAuthService');
const { app } = require('../src/server');

describe('Apple Auth Tests', () => {
  let originalVerify;

  before(() => {
    originalVerify = appleAuthService.verifyAppleToken;
  });

  after(() => {
    appleAuthService.verifyAppleToken = originalVerify;
  });

  it('rejects requests without identityToken or userIdentifier with 400', async () => {
    const res = await request(app)
      .post('/api/auth/apple')
      .send({});
    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
    assert.match(res.body.message, /Apple authorization credentials are required/i);
  });

  it('returns 401 when Apple token verification fails', async () => {
    appleAuthService.verifyAppleToken = async () => {
      throw new Error('Invalid token');
    };

    const res = await request(app)
      .post('/api/auth/apple')
      .send({ identityToken: 'invalid_token_123' });
    assert.equal(res.status, 401);
    assert.equal(res.body.success, false);
  });

  it('signs in a new user with Apple (first-time: name + email provided)', async () => {
    const mockAppleId = `001234.apple.${Date.now()}`;
    appleAuthService.verifyAppleToken = async () => {
      return {
        appleId: mockAppleId,
        email: 'testapple@privaterelay.appleid.com',
        name: 'Apple Reviewer',
        isPrivateEmail: true,
      };
    };

    const res = await request(app)
      .post('/api/auth/apple')
      .send({
        identityToken: 'mock_valid_token',
        userIdentifier: mockAppleId,
        email: 'testapple@privaterelay.appleid.com',
        fullName: { givenName: 'Apple', familyName: 'Reviewer' },
      });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.token);
    assert.equal(res.body.user.appleId, mockAppleId);
    assert.equal(res.body.user.email, 'testapple@privaterelay.appleid.com');
    assert.equal(res.body.user.ownerName, 'Apple Reviewer');
  });

  it('signs in returning user (subsequent sign-in: Apple sends NO name or email)', async () => {
    const mockAppleId = `001234.apple.returning.${Date.now()}`;

    // 1. First time
    appleAuthService.verifyAppleToken = async () => {
      return {
        appleId: mockAppleId,
        email: 'returning@example.com',
        name: 'Jane Doe',
      };
    };
    const res1 = await request(app)
      .post('/api/auth/apple')
      .send({ identityToken: 'mock_token', userIdentifier: mockAppleId });
    assert.equal(res1.status, 200);

    // 2. Returning - no name and no email in token
    appleAuthService.verifyAppleToken = async () => {
      return {
        appleId: mockAppleId,
        email: '',
        name: '',
      };
    };
    const res2 = await request(app)
      .post('/api/auth/apple')
      .send({ identityToken: 'mock_token', userIdentifier: mockAppleId });
    assert.equal(res2.status, 200);
    assert.equal(res2.body.user.id, res1.body.user.id);
    assert.equal(res2.body.user.email, 'returning@example.com');
  });

  it('links appleId to existing account when email matches', async () => {
    const commonEmail = `existing.${Date.now()}@example.com`;
    // Create existing user with that email
    await memoryUsers.create({
      username: `user_${Date.now().toString().slice(-6)}`,
      email: commonEmail,
      phone: '9999988888',
      ownerName: 'Existing Owner',
    });

    const mockAppleId = `001234.linked.${Date.now()}`;
    appleAuthService.verifyAppleToken = async () => {
      return {
        appleId: mockAppleId,
        email: commonEmail,
        name: 'Linked Apple User',
      };
    };

    const res = await request(app)
      .post('/api/auth/apple')
      .send({ identityToken: 'mock_token', userIdentifier: mockAppleId });

    assert.equal(res.status, 200);
    assert.equal(res.body.user.email, commonEmail);
    assert.equal(res.body.user.appleId, mockAppleId);
  });

  it('cryptographically verifies RS256 token using mock JWKS public key', async () => {
    const { publicKey, privateKey } = crypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
    });
    const jwk = publicKey.export({ format: 'jwk' });
    jwk.kid = 'test-kid-123';
    jwk.use = 'sig';
    jwk.alg = 'RS256';

    appleAuthService.setMockAppleKeys([jwk]);

    const appleSub = 'test-rsa-apple-sub-456';
    const signedToken = jwt.sign(
      {
        sub: appleSub,
        email: 'rsa_test@privaterelay.appleid.com',
        iss: 'https://appleid.apple.com',
        aud: process.env.APPLE_BUNDLE_ID || 'com.lumen.lumenStudio',
      },
      privateKey,
      {
        algorithm: 'RS256',
        keyid: 'test-kid-123',
        expiresIn: '1h',
      },
    );

    // Restore real verifyAppleToken
    appleAuthService.verifyAppleToken = originalVerify;
    const verified = await appleAuthService.verifyAppleToken({
      identityToken: signedToken,
      userIdentifier: appleSub,
    });

    assert.equal(verified.appleId, appleSub);
    assert.equal(verified.email, 'rsa_test@privaterelay.appleid.com');
    assert.equal(verified.isPrivateEmail, true);
  });
});
