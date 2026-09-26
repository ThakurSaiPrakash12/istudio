'use strict';

const assert = require('node:assert/strict');
const { describe, it, before, after } = require('node:test');
const request = require('supertest');

process.env.JWT_SECRET = 'test-secret-security-suite-32chars!!';
process.env.NODE_ENV = 'test';

const memoryUsers = require('../src/store/memoryUsers');
memoryUsers.enabled = true;

const googleAuthService = require('../src/services/googleAuthService');
const { app } = require('../src/server');

describe('Google OAuth & Google API Tests', () => {
  let originalVerify;

  before(() => {
    originalVerify = googleAuthService.verifyGoogleToken;
  });

  after(() => {
    googleAuthService.verifyGoogleToken = originalVerify;
  });

  it('rejects requests without idToken or accessToken with 400', async () => {
    const res = await request(app)
      .post('/api/auth/google')
      .send({});
    assert.equal(res.status, 400);
    assert.equal(res.body.success, false);
    assert.match(res.body.message, /Google authorization token is required/i);
  });

  it('returns 401 when Google token verification fails', async () => {
    googleAuthService.verifyGoogleToken = async () => {
      throw new Error('Invalid token');
    };

    const res = await request(app)
      .post('/api/auth/google')
      .send({ idToken: 'invalid_token_123' });
    assert.equal(res.status, 401);
    assert.equal(res.body.success, false);
  });

  it('signs in a new user with Google and returns JWT and user profile', async () => {
    const mockGoogleId = `gid_${Date.now()}`;
    googleAuthService.verifyGoogleToken = async () => {
      return {
        googleId: mockGoogleId,
        email: 'alex.creator@example.com',
        name: 'Alex Creator',
        picture: 'https://lh3.googleusercontent.com/a/mock-pic',
        emailVerified: true,
      };
    };

    const res = await request(app)
      .post('/api/auth/google')
      .send({ idToken: 'valid_mock_token' });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.token);
    assert.equal(res.body.user.googleId, mockGoogleId);
    assert.equal(res.body.user.email, 'alex.creator@example.com');
    assert.equal(res.body.user.ownerName, 'Alex Creator');
    assert.equal(res.body.user.logoUrl, 'https://lh3.googleusercontent.com/a/mock-pic');
  });

  it('returns existing user when same Google user signs in again', async () => {
    const mockGoogleId = `gid_existing_${Date.now()}`;
    googleAuthService.verifyGoogleToken = async () => {
      return {
        googleId: mockGoogleId,
        email: 'repeated@example.com',
        name: 'Repeated User',
        picture: '',
        emailVerified: true,
      };
    };

    // First login
    const firstRes = await request(app)
      .post('/api/auth/google')
      .send({ idToken: 'valid_mock_token_1' });
    assert.equal(firstRes.status, 200);
    const userId = firstRes.body.user.id;

    // Second login
    const secondRes = await request(app)
      .post('/api/auth/google')
      .send({ idToken: 'valid_mock_token_2' });
    assert.equal(secondRes.status, 200);
    assert.equal(secondRes.body.user.id, userId);
  });

  it('links googleId if existing user has matching email', async () => {
    const testEmail = `match_${Date.now()}@example.com`;
    // Create pre-existing user with email
    const preUser = await memoryUsers.create({
      username: `user_${Date.now().toString().slice(-4)}`,
      email: testEmail,
      phone: '9988776655',
      password: 'hashed_password_123',
    });

    const mockGoogleId = `gid_link_${Date.now()}`;
    googleAuthService.verifyGoogleToken = async () => {
      return {
        googleId: mockGoogleId,
        email: testEmail,
        name: 'Matched User',
        picture: 'https://pic.example.com/matched.jpg',
        emailVerified: true,
      };
    };

    const res = await request(app)
      .post('/api/auth/google')
      .send({ idToken: 'valid_mock_token_link' });

    assert.equal(res.status, 200);
    assert.equal(res.body.user.id, preUser._id);
    assert.equal(res.body.user.googleId, mockGoogleId);
  });

  it('googleAuthService provides Google API and OAuth2 client', () => {
    const client = googleAuthService.getOAuth2Client();
    assert.ok(client);

    const oauth2 = googleAuthService.getGoogleApi('oauth2', 'v2');
    assert.ok(oauth2);
    assert.ok(oauth2.userinfo);
  });
});
