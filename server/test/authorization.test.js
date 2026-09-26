'use strict';

/**
 * Authorization security tests.
 * Runs fully in-memory — no MongoDB or Cloudinary required.
 */

const assert = require('node:assert/strict');
const { describe, it, before } = require('node:test');
const request = require('supertest');

// Must be set before requiring server modules
process.env.JWT_SECRET = 'test-secret-security-suite-32chars!!';
process.env.NODE_ENV = 'test';
// No MONGODB_URI → connectDb activates memory store

// Activate memory store directly before any module uses it
const memoryUsers = require('../src/store/memoryUsers');
memoryUsers.enabled = true;

const jwt = require('jsonwebtoken');
const { app } = require('../src/server');

// ─── helpers ─────────────────────────────────────────────────────────────────

const { randomUUID } = require('crypto');

// Use randomUUID since the memory store uses UUIDs, not Mongo ObjectIds
const USER_A_ID = randomUUID();
const USER_B_ID = randomUUID();

function makeToken(userId, username) {
  return jwt.sign(
    { id: userId, username, phone: '0000000000' },
    process.env.JWT_SECRET,
    { algorithm: 'HS256', expiresIn: '1h' },
  );
}

function auth(token) {
  return { Authorization: `Bearer ${token}` };
}

const tokenA = makeToken(USER_A_ID, 'userA');
const tokenB = makeToken(USER_B_ID, 'userB');

// ─── 1. Unauthenticated → 401 ────────────────────────────────────────────────

describe('Unauthenticated requests → 401', () => {
  const routes = [
    ['GET',  '/api/events'],
    ['GET',  '/api/clients'],
    ['GET',  '/api/invoices'],
    ['GET',  `/api/events/${randomUUID()}/payments`],
    ['GET',  `/api/events/${randomUUID()}/expenses`],
    ['GET',  `/api/events/${randomUUID()}/deliverables`],
    ['GET',  `/api/payments/${randomUUID()}`],
    ['GET',  `/api/expenses/${randomUUID()}`],
    ['GET',  `/api/deliverables/${randomUUID()}`],
  ];

  for (const [method, path] of routes) {
    it(`${method} ${path}`, async () => {
      const res = await request(app)[method.toLowerCase()](path);
      assert.equal(res.status, 401, `Expected 401, got ${res.status}`);
    });
  }
});

// ─── 2. Cross-user invoice isolation ─────────────────────────────────────────

describe('Cross-user invoice isolation', () => {
  let invoiceIdA;

  before(async () => {
    const res = await request(app)
      .post('/api/invoices')
      .set(auth(tokenA))
      .send({
        eventName: "User A's Wedding",
        contactName: 'Alice',
        phone: '9876543210',
        address: '1 Alpha Street, Mumbai',
        dueDate: new Date(Date.now() + 86400000).toISOString(),
        deliverables: [{ name: 'Photography', cost: 5000 }],
      });
    assert.equal(res.status, 201, `Invoice setup failed: ${JSON.stringify(res.body)}`);
    invoiceIdA = res.body.invoice.id;
  });

  it('User A can read their own invoice', async () => {
    const res = await request(app)
      .get(`/api/invoices/${invoiceIdA}`)
      .set(auth(tokenA));
    assert.equal(res.status, 200);
    assert.equal(res.body.invoice.id, invoiceIdA);
  });

  it('User B CANNOT read User A\'s invoice → 404', async () => {
    const res = await request(app)
      .get(`/api/invoices/${invoiceIdA}`)
      .set(auth(tokenB));
    assert.equal(res.status, 404, `B must not see A's invoice, got ${res.status}`);
  });

  it('User B CANNOT update User A\'s invoice → 404', async () => {
    const res = await request(app)
      .patch(`/api/invoices/${invoiceIdA}`)
      .set(auth(tokenB))
      .send({ eventName: 'Hijacked' });
    assert.equal(res.status, 404);
  });

  it('User B CANNOT delete User A\'s invoice → 404', async () => {
    const res = await request(app)
      .delete(`/api/invoices/${invoiceIdA}`)
      .set(auth(tokenB));
    assert.equal(res.status, 404);
  });

  it('User B CANNOT mark User A\'s invoice as paid → 404', async () => {
    const res = await request(app)
      .post(`/api/invoices/${invoiceIdA}/paid`)
      .set(auth(tokenB));
    assert.equal(res.status, 404);
  });

  it('Invoice still intact and belongs to A after all B attacks', async () => {
    const res = await request(app)
      .get(`/api/invoices/${invoiceIdA}`)
      .set(auth(tokenA));
    assert.equal(res.status, 200);
    assert.equal(res.body.invoice.id, invoiceIdA);
  });
});

// ─── 3. Spoofed userId in request body is ignored ────────────────────────────

describe('Spoofed userId in body is ignored', () => {
  it('Invoice created with body.userId=B still belongs to A', async () => {
    const res = await request(app)
      .post('/api/invoices')
      .set(auth(tokenA))
      .send({
        userId: USER_B_ID,  // attacker attempts to assign ownership to B
        eventName: 'Spoof Test',
        contactName: 'Eve',
        phone: '9999999999',
        address: '2 Evil Lane, Delhi',
        dueDate: new Date(Date.now() + 86400000).toISOString(),
        deliverables: [{ name: 'HackService', cost: 1 }],
      });
    assert.equal(res.status, 201, `Create failed: ${JSON.stringify(res.body)}`);

    const id = res.body.invoice.id;

    // B cannot read it
    const resB = await request(app)
      .get(`/api/invoices/${id}`)
      .set(auth(tokenB));
    assert.equal(resB.status, 404, 'Spoofed userId must not grant B access');

    // A can read it
    const resA = await request(app)
      .get(`/api/invoices/${id}`)
      .set(auth(tokenA));
    assert.equal(resA.status, 200);
  });
});

// ─── 4. Invalid JWT scenarios ─────────────────────────────────────────────────

describe('Invalid JWT tokens → 401', () => {
  it('Tampered token (last 5 chars replaced)', async () => {
    const tampered = `${tokenA.slice(0, -5)}XXXXX`;
    const res = await request(app)
      .get('/api/invoices')
      .set('Authorization', `Bearer ${tampered}`);
    assert.equal(res.status, 401);
  });

  it('Token signed with wrong secret', async () => {
    const fake = jwt.sign(
      { id: USER_A_ID, username: 'hacker', phone: '0000000000' },
      'completely-wrong-secret',
      { algorithm: 'HS256' },
    );
    const res = await request(app)
      .get('/api/invoices')
      .set('Authorization', `Bearer ${fake}`);
    assert.equal(res.status, 401);
  });

  it('Missing Authorization header entirely', async () => {
    const res = await request(app).get('/api/invoices');
    assert.equal(res.status, 401);
  });

  it('Malformed header — no Bearer prefix', async () => {
    const res = await request(app)
      .get('/api/invoices')
      .set('Authorization', tokenA);  // missing "Bearer " prefix
    assert.equal(res.status, 401);
  });

  it('Empty Bearer token', async () => {
    const res = await request(app)
      .get('/api/invoices')
      .set('Authorization', 'Bearer ');
    assert.equal(res.status, 401);
  });
});
