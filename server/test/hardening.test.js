const assert = require('assert');
const { spawn } = require('child_process');
const mongoose = require('mongoose');
const request = require('supertest');

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'hardening-test-secret-with-enough-length';
process.env.MONGODB_URI = process.env.MONGODB_TEST_URI || 'mongodb://127.0.0.1:27017/lumen_studio_hardening_test';
process.env.CLOUDINARY_TEST_MODE = 'true';
process.env.CLOUDINARY_CLOUD_NAME = 'test';
process.env.CLOUDINARY_API_KEY = 'test';
process.env.CLOUDINARY_API_SECRET = 'test';

const { app } = require('../src/server');
const { connectDb } = require('../src/config/db');
const Event = require('../src/models/Event');
const Payment = require('../src/models/Payment');
const Expense = require('../src/models/Expense');
const Deliverable = require('../src/models/Deliverable');
const { validateProductionConfig, parseCorsOrigins } = require('../src/config/runtime');

async function waitForHealth(url) {
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch (_) {}
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error('Restarted backend did not become ready.');
}

const auth = (token) => ({ Authorization: `Bearer ${token}` });
const expectStatus = async (promise, status) => {
  const response = await promise;
  assert.strictEqual(response.status, status, JSON.stringify(response.body));
  return response.body;
};

async function run() {
  await connectDb();
  await mongoose.connection.db.dropDatabase();
  const suffix = Date.now();
  const signup = async (username, phone) => (await request(app).post('/api/auth/signup').send({
    username, phone, password: 'hardening-password-123',
  })).body;
  const userA = await signup(`ha_${suffix}`, `930000${String(suffix).slice(-4)}`);
  const userB = await signup(`hb_${suffix}`, `940000${String(suffix).slice(-4)}`);
  const client = (await request(app).post('/api/clients').set(auth(userA.token)).send({
    name: 'Hardening Client', phone: '9000000099',
  })).body.client;
  const eventBody = {
    clientId: client.id,
    title: 'Idempotent Event',
    eventType: 'Wedding',
    startsAt: '2032-01-01T10:00:00.000Z',
    location: 'Test Venue',
    status: 'upcoming',
    totalAmount: 100,
  };
  const eventResponses = await Promise.all([
    request(app).post('/api/events').set(auth(userA.token)).set('Idempotency-Key', 'event-key').send(eventBody),
    request(app).post('/api/events').set(auth(userA.token)).set('Idempotency-Key', 'event-key').send(eventBody),
  ]);
  assert.ok(eventResponses.every((item) => item.status === 201));
  assert.strictEqual(eventResponses[0].body.event.id, eventResponses[1].body.event.id);
  assert.strictEqual(await Event.countDocuments({ title: eventBody.title }), 1);
  const event = eventResponses[0].body.event;
  const differentKey = await request(app).post('/api/events').set(auth(userA.token)).set('Idempotency-Key', 'event-key-2').send({ ...eventBody, title: 'Different Key' });
  assert.strictEqual(differentKey.status, 201);
  const paymentBody = { title: 'Payment', amount: 10, paidAt: '2032-01-01T10:00:00.000Z', method: 'upi' };
  const paymentResponses = await Promise.all([
    request(app).post(`/api/events/${event.id}/payments`).set(auth(userA.token)).set('Idempotency-Key', 'payment-key').send(paymentBody),
    request(app).post(`/api/events/${event.id}/payments`).set(auth(userA.token)).set('Idempotency-Key', 'payment-key').send(paymentBody),
  ]);
  assert.ok(paymentResponses.every((item) => item.status === 201));
  assert.strictEqual(paymentResponses[0].body.payment.id, paymentResponses[1].body.payment.id);
  assert.strictEqual(await Payment.countDocuments({ eventId: event.id, title: 'Payment' }), 1);
  const concurrentPayments = await Promise.all([60, 60].map((amount, index) => request(app)
    .post(`/api/events/${event.id}/payments`)
    .set(auth(userA.token))
    .set('Idempotency-Key', `payment-race-${index}`)
    .send({ ...paymentBody, title: `Race ${index}`, amount })));
  assert.deepStrictEqual(concurrentPayments.map((item) => item.status).sort(), [201, 400]);
  const expense = { title: 'Expense', amount: 5, category: 'Travel', incurredAt: '2032-01-01T10:00:00.000Z' };
  const expenseResponses = await Promise.all([1, 2].map(() => request(app).post(`/api/events/${event.id}/expenses`)
    .set(auth(userA.token)).set('Idempotency-Key', 'expense-key').send(expense)));
  assert.ok(expenseResponses.every((item) => item.status === 201));
  assert.strictEqual(await Expense.countDocuments({ eventId: event.id, title: 'Expense' }), 1);
  const deliverable = { title: 'Editing', stage: 'Post', isCompleted: false };
  const deliverableResponses = await Promise.all([1, 2].map(() => request(app).post(`/api/events/${event.id}/deliverables`)
    .set(auth(userA.token)).set('Idempotency-Key', 'deliverable-key').send(deliverable)));
  assert.ok(deliverableResponses.every((item) => item.status === 201));
  assert.strictEqual(await Deliverable.countDocuments({ eventId: event.id, title: 'Editing' }), 1);
  const invoiceBody = {
    eventName: 'Hardening Invoice', contactName: 'Client', phone: '9000000098', address: 'Address',
    dueDate: '2032-02-01T00:00:00.000Z', deliverables: [{ name: 'Coverage', cost: 100 }],
  };
  const invoiceResponse = await request(app).post('/api/invoices').set(auth(userA.token)).set('Idempotency-Key', 'invoice-key').send(invoiceBody);
  assert.strictEqual(invoiceResponse.status, 201);
  const invoice = invoiceResponse.body.invoice;
  const invoiceRetries = await Promise.all([1, 2].map(() => request(app).post(`/api/invoices/${invoice.id}/partial`)
    .set(auth(userA.token)).set('Idempotency-Key', 'partial-key').send({ amount: 10 })));
  assert.ok(invoiceRetries.every((item) => item.status === 200));
  assert.strictEqual(invoiceRetries[0].body.invoice.amountReceived, invoiceRetries[1].body.invoice.amountReceived);
  const invoiceRace = await Promise.all([1, 2].map((index) => request(app).post(`/api/invoices/${invoice.id}/partial`)
    .set(auth(userA.token)).set('Idempotency-Key', `partial-race-${index}`).send({ amount: 60 })));
  assert.deepStrictEqual(invoiceRace.map((item) => item.status).sort(), [200, 400]);
  const invoiceAfter = (await request(app).get(`/api/invoices/${invoice.id}`).set(auth(userA.token))).body.invoice;
  assert.strictEqual(invoiceAfter.amountReceived, 70);
  const profile = await request(app).patch('/api/auth/profile').set(auth(userA.token)).send({ studioName: 'Hardening Studio' });
  assert.strictEqual(profile.status, 200);
  const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', 'base64');
  const logo = await request(app).post('/api/auth/logo').set(auth(userA.token)).attach('logo', png, 'logo.png');
  assert.strictEqual(logo.status, 200);
  assert.ok(logo.body.imageUrl.startsWith('https://res.cloudinary.com/'));
  await expectStatus(request(app).post('/api/auth/logo').attach('logo', png, 'logo.png'), 401);
  await expectStatus(request(app).post('/api/auth/logo').set(auth(userB.token)).attach('logo', Buffer.from('bad'), 'logo.png'), 400);
  await expectStatus(request(app).get('/api/health/live'), 200);
  await expectStatus(request(app).get('/api/health/ready'), 200);
  assert.throws(() => validateProductionConfig({ NODE_ENV: 'production', JWT_SECRET: 'short' }), /Missing production configuration/);
  assert.throws(() => parseCorsOrigins({ CORS_ORIGINS: 'not-a-url' }), /Invalid CORS origin/);
  await mongoose.disconnect();
  const backend = spawn(process.execPath, ['src/server.js'], {
    cwd: require('path').join(__dirname, '..'),
    env: { ...process.env, PORT: '5013' },
    stdio: 'ignore',
  });
  try {
    await waitForHealth('http://127.0.0.1:5013/api/health/live');
    const login = await fetch('http://127.0.0.1:5013/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: userA.user.phone, password: 'hardening-password-123' }),
    });
    assert.strictEqual(login.status, 200);
    const loginBody = await login.json();
    const persisted = await fetch(`http://127.0.0.1:5013/api/invoices/${invoice.id}`, {
      headers: { Authorization: `Bearer ${loginBody.token}` },
    });
    assert.strictEqual(persisted.status, 200);
    const persistedInvoice = (await persisted.json()).invoice;
    assert.strictEqual(persistedInvoice.total, 100);
    assert.strictEqual(persistedInvoice.amountReceived, 70);
    assert.strictEqual(persistedInvoice.pendingAmount, 30);
    assert.strictEqual(persistedInvoice.status, 'partial');
    assert.strictEqual(persistedInvoice.dueDate, invoice.dueDate);
  } finally {
    backend.kill();
  }
  console.log('HARDENING_TESTS_PASSED');
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(async () => {
  if (mongoose.connection.readyState !== 0) await mongoose.disconnect();
});