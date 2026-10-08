'use strict';

const assert = require('node:assert/strict');
const { describe, it, before } = require('node:test');
const request = require('supertest');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'test-secret-security-suite-32chars!!';
process.env.NODE_ENV = 'test';

const memoryUsers = require('../src/store/memoryUsers');
memoryUsers.enabled = true;
const memoryInvoices = require('../src/store/memoryInvoices');
memoryInvoices.enabled = true;
const { app } = require('../src/server');

describe('Photographer Categories & Search API', () => {
  let userToken;
  let userA;
  let userNear;
  let userFar;
  let userNoCoords;

  before(async () => {
    userA = memoryUsers.create({
      username: 'studio_alpha',
      email: 'alpha@example.com',
      phone: '9876543211',
      password: 'dummyhash',
      studioName: 'Studio Alpha',
      address: 'Hyderabad, Banjara Hills',
      city: 'Hyderabad',
      latitude: 17.4156,
      longitude: 78.4357,
      categories: ['Traditional photographer'],
    });

    userNear = memoryUsers.create({
      username: 'candid_lens',
      email: 'candid@example.com',
      phone: '9876543210',
      password: 'dummyhash',
      studioName: 'Candid Lens Studio',
      address: 'Hyderabad, Jubilee Hills',
      city: 'Hyderabad',
      latitude: 17.4319,
      longitude: 78.4073,
      categories: ['Candid photographer', 'Cinematic Vidiographer'],
    });

    userFar = memoryUsers.create({
      username: 'far_studio',
      email: 'far@example.com',
      phone: '9876543212',
      password: 'dummyhash',
      studioName: 'Far Studio',
      address: 'Warangal',
      city: 'Warangal',
      latitude: 17.9689,
      longitude: 79.5941,
      categories: ['Candid photographer'],
    });

    userNoCoords = memoryUsers.create({
      username: 'no_coords_studio',
      email: 'nocoords@example.com',
      phone: '9876543213',
      password: 'dummyhash',
      studioName: 'No Coords Studio',
      address: 'Somewhere',
      city: 'Hyderabad',
      categories: ['Candid photographer'],
    });

    userToken = jwt.sign(
      { id: userA._id, username: userA.username, email: userA.email },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );
  });

  it('searches photographers by location and category', async () => {
    const res = await request(app)
      .get('/api/photographers/search')
      .set('Authorization', `Bearer ${userToken}`)
      .query({ location: 'Hyderabad', category: 'Candid photographer' });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(Array.isArray(res.body.photographers));
    assert.ok(res.body.photographers.length >= 1);
    const found = res.body.photographers.find((p) => p.username === 'candid_lens');
    assert.ok(found, 'Created photographer B should be found');
    assert.ok(found.categories.includes('Candid photographer'));
  });

  it('calculates real lat/lng distance and sorts nearest first', async () => {
    const res = await request(app)
      .get('/api/photographers/nearby')
      .set('Authorization', `Bearer ${userToken}`)
      .query({
        lat: 17.4156,
        lng: 78.4357,
        category: 'Candid photographer',
      });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.photographers.length >= 2);

    const near = res.body.photographers.find((p) => p.username === 'candid_lens');
    const far = res.body.photographers.find((p) => p.username === 'far_studio');
    const noCoords = res.body.photographers.find((p) => p.username === 'no_coords_studio');

    assert.ok(typeof near.distanceKm === 'number');
    assert.ok(typeof far.distanceKm === 'number');
    assert.ok(near.distanceKm < far.distanceKm, 'Near photographer must have smaller distance');
    assert.equal(noCoords.distanceKm, null, 'Photographer without coords safely gets null distance');

    // Nearest photographer is sorted before farther photographer
    const nearIdx = res.body.photographers.findIndex((p) => p.username === 'candid_lens');
    const farIdx = res.body.photographers.findIndex((p) => p.username === 'far_studio');
    assert.ok(nearIdx < farIdx, 'Nearest photographer must be sorted first');
  });

  it('safely handles missing origin coordinates without errors', async () => {
    const res = await request(app)
      .get('/api/photographers/nearby')
      .set('Authorization', `Bearer ${userToken}`);

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    for (const p of res.body.photographers) {
      assert.equal(p.distanceKm, null, 'Without coordinates distance is null');
    }
  });

  it('updates categories on user profile update via PATCH /api/auth/profile', async () => {
    const res = await request(app)
      .patch('/api/auth/profile')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        categories: [
          'Traditional photographer',
          'Traditional Vidiographer',
          'Drone s',
          'Led screen s',
        ],
      });

    assert.equal(res.status, 200);
    assert.equal(res.body.success, true);
    assert.ok(res.body.user.categories.includes('Drone s'));
    assert.ok(res.body.user.categories.includes('Led screen s'));
  });
});

describe('Invoice Events Link API & Receipt Idempotency', () => {
  let userToken;

  before(async () => {
    const user = memoryUsers.findByEmail('alpha@example.com');
    userToken = jwt.sign(
      { id: user._id, username: user.username, email: user.email },
      process.env.JWT_SECRET,
      { expiresIn: '1h' }
    );
  });

  it('creates an invoice linked to an event and retrieves event invoices', async () => {
    const createRes = await request(app)
      .post('/api/invoices')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        number: 'INV-TEST-001',
        eventName: 'Grand Wedding Reception',
        contactName: 'Ramesh Kumar',
        phone: '9123456780',
        address: 'Plot 42, Jubilee Hills, Hyderabad',
        dueDate: new Date(Date.now() + 86400000).toISOString(),
        eventId: 'event_rec_123',
        paymentId: 'pay_999',
        amountReceived: 25000,
        deliverables: [
          { name: 'Full Day Photography', cost: 50000 },
        ],
      });

    assert.equal(createRes.status, 201);
    assert.equal(createRes.body.success, true);
    assert.equal(createRes.body.invoice.eventId, 'event_rec_123');
    assert.equal(createRes.body.invoice.paymentId, 'pay_999');

    // Retrieve invoices for event
    const getRes = await request(app)
      .get('/api/invoices')
      .set('Authorization', `Bearer ${userToken}`)
      .query({ eventId: 'event_rec_123' });

    assert.equal(getRes.status, 200);
    assert.equal(getRes.body.success, true);
    assert.ok(getRes.body.invoices.length >= 1);
    assert.equal(getRes.body.invoices[0].number, createRes.body.invoice.number);
    assert.equal(getRes.body.invoices[0].eventId, 'event_rec_123');

    // Verify findByPaymentId returns this exact receipt
    const foundByPay = memoryInvoices.findByPaymentId('pay_999', userToken ? (jwt.decode(userToken)).id : '');
    assert.ok(foundByPay);
    assert.equal(foundByPay.paymentId, 'pay_999');
  });
});
