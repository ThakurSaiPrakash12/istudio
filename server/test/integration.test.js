const assert = require('assert');
const { spawn } = require('child_process');
const mongoose = require('mongoose');
const request = require('supertest');

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'integration-test-secret-with-enough-length';
process.env.CLOUDINARY_TEST_MODE = 'true';
process.env.MONGODB_URI = process.env.MONGODB_TEST_URI || 'mongodb://127.0.0.1:27017/lumen_studio_integration_test';

const { app } = require('../src/server');
const { connectDb } = require('../src/config/db');
const memoryUsers = require('../src/store/memoryUsers');
const Payment = require('../src/models/Payment');

async function signup(username, phone) {
  const response = await request(app).post('/api/auth/signup').send({
    username,
    phone,
    password: 'integration-password-123',
  });
  assert.strictEqual(response.status, 201, JSON.stringify(response.body));
  assert.ok(response.body.token);
  return response.body;
}

async function expectStatus(promise, statuses = [404, 403]) {
  const response = await promise;
  assert.ok(statuses.includes(response.status), `Expected ${statuses}, got ${response.status}: ${JSON.stringify(response.body)}`);
}

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

async function run() {
  await connectDb();
  assert.strictEqual(memoryUsers.enabled, false, 'Integration test must use MongoDB, not memory storage.');
  await mongoose.connection.db.dropDatabase();

  const userA = await signup(`user_a_${Date.now()}`, '9000000001');
  const userB = await signup(`user_b_${Date.now()}`, '9000000002');

  const emptyClients = await request(app).get('/api/clients').set('Authorization', `Bearer ${userB.token}`);
  const emptyEvents = await request(app).get('/api/events').set('Authorization', `Bearer ${userB.token}`);
  assert.deepStrictEqual(emptyClients.body.clients, []);
  assert.deepStrictEqual(emptyEvents.body.events, []);

  const clientAResponse = await request(app).post('/api/clients').set('Authorization', `Bearer ${userA.token}`).send({
    name: 'Client A', phone: '9000000011', email: 'a@example.com', address: 'A Street',
  });
  assert.strictEqual(clientAResponse.status, 201, JSON.stringify(clientAResponse.body));
  const clientA = clientAResponse.body.client;

  const eventAResponse = await request(app).post('/api/events').set('Authorization', `Bearer ${userA.token}`).send({
    clientId: clientA.id, title: 'Event A', eventType: 'Wedding', startsAt: '2030-01-01T10:00:00.000Z',
    startTime: '10:00 AM', endTime: '06:00 PM', location: 'A Venue', status: 'upcoming', totalAmount: 100000,
  });
  assert.strictEqual(eventAResponse.status, 201, JSON.stringify(eventAResponse.body));
  const eventA = eventAResponse.body.event;

  async function addPayment(token, eventId, amount, title) {
    const response = await request(app).post(`/api/events/${eventId}/payments`).set('Authorization', `Bearer ${token}`).send({
      title, amount, paidAt: '2030-01-01T10:00:00.000Z', method: 'upi', reference: title,
    });
    assert.strictEqual(response.status, 201, JSON.stringify(response.body));
    return response.body.payment;
  }
  const paymentA1 = await addPayment(userA.token, eventA.id, 30000, 'Payment A1');
  const proofPng = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
    'base64',
  );
  const proofUpload = await request(app)
    .post(`/api/payments/${paymentA1.id}/proof`)
    .set('Authorization', `Bearer ${userA.token}`)
    .attach('proof', proofPng, 'payment-proof.png');
  assert.strictEqual(proofUpload.status, 200, JSON.stringify(proofUpload.body));
  const proofUrl = proofUpload.body.payment.proof;
  assert.ok(proofUrl.startsWith('https://res.cloudinary.com/'));
  assert.ok(!proofUrl.startsWith('data:'));
  assert.ok(!JSON.stringify(proofUpload.body).includes(process.env.CLOUDINARY_API_SECRET));
  const storedPayment = await Payment.findById(paymentA1.id).lean();
  assert.ok(storedPayment.proofUrl.startsWith('https://res.cloudinary.com/'));
  assert.ok(!storedPayment.proofUrl.startsWith('data:'));
  const invalidProof = await request(app)
    .post(`/api/payments/${paymentA1.id}/proof`)
    .set('Authorization', `Bearer ${userA.token}`)
    .attach('proof', Buffer.from('<script>invalid</script>'), 'proof.svg');
  assert.strictEqual(invalidProof.status, 400);
  const oversizedProof = await request(app)
    .post(`/api/payments/${paymentA1.id}/proof`)
    .set('Authorization', `Bearer ${userA.token}`)
    .attach('proof', Buffer.alloc(10 * 1024 * 1024 + 1, 1), 'large.png');
  assert.strictEqual(oversizedProof.status, 400);
  await addPayment(userA.token, eventA.id, 20000, 'Payment A2');

  const expenseAResponse = await request(app).post(`/api/events/${eventA.id}/expenses`).set('Authorization', `Bearer ${userA.token}`).send({
    title: 'Expense A1', amount: 10000, category: 'Crew', incurredAt: '2030-01-01T10:00:00.000Z',
  });
  assert.strictEqual(expenseAResponse.status, 201, JSON.stringify(expenseAResponse.body));
  const expenseA = expenseAResponse.body.expense;
  await request(app).post(`/api/events/${eventA.id}/expenses`).set('Authorization', `Bearer ${userA.token}`).send({
    title: 'Expense A2', amount: 5000, category: 'Travel', incurredAt: '2030-01-01T10:00:00.000Z',
  });

  const deliverableAResponse = await request(app).post(`/api/events/${eventA.id}/deliverables`).set('Authorization', `Bearer ${userA.token}`).send({
    title: 'Deliverable A', stage: 'Editing', isCompleted: false,
  });
  assert.strictEqual(deliverableAResponse.status, 201, JSON.stringify(deliverableAResponse.body));
  const deliverableA = deliverableAResponse.body.deliverable;
  const completedA = await request(app).put(`/api/deliverables/${deliverableA.id}`).set('Authorization', `Bearer ${userA.token}`).send({ isCompleted: true });
  assert.strictEqual(completedA.status, 200, JSON.stringify(completedA.body));

  const eventARead = await request(app).get(`/api/events/${eventA.id}`).set('Authorization', `Bearer ${userA.token}`);
  assert.strictEqual(eventARead.status, 200);
  assert.deepStrictEqual({
    amountReceived: eventARead.body.event.amountReceived,
    remainingAmount: eventARead.body.event.remainingAmount,
    totalExpenses: eventARead.body.event.totalExpenses,
    netProfit: eventARead.body.event.netProfit,
  }, { amountReceived: 50000, remainingAmount: 50000, totalExpenses: 15000, netProfit: 35000 });
  for (const [path, key] of [
    [`/api/payments/${paymentA1.id}`, 'payment'],
    [`/api/expenses/${expenseA.id}`, 'expense'],
    [`/api/deliverables/${deliverableA.id}`, 'deliverable'],
  ]) {
    const response = await request(app).get(path).set('Authorization', `Bearer ${userA.token}`);
    assert.strictEqual(response.status, 200, JSON.stringify(response.body));
    assert.ok(response.body[key]);
  }
  for (const [path, key] of [
    [`/api/events/${eventA.id}/payments`, 'payments'],
    [`/api/events/${eventA.id}/expenses`, 'expenses'],
    [`/api/events/${eventA.id}/deliverables`, 'deliverables'],
  ]) {
    const response = await request(app).get(path).set('Authorization', `Bearer ${userA.token}`);
    assert.strictEqual(response.status, 200, JSON.stringify(response.body));
    assert.ok(response.body[key].length > 0);
  }

  const clientBResponse = await request(app).post('/api/clients').set('Authorization', `Bearer ${userB.token}`).send({
    name: 'Client B', phone: '9000000022', email: 'b@example.com', address: 'B Street',
  });
  assert.strictEqual(clientBResponse.status, 201);
  const clientB = clientBResponse.body.client;
  const eventBResponse = await request(app).post('/api/events').set('Authorization', `Bearer ${userB.token}`).send({
    clientId: clientB.id, title: 'Event B', eventType: 'Portrait', startsAt: '2030-02-01T10:00:00.000Z',
    location: 'B Venue', status: 'upcoming', totalAmount: 50000,
  });
  assert.strictEqual(eventBResponse.status, 201);
  const eventB = eventBResponse.body.event;
  const paymentBResponse = await request(app).post(`/api/events/${eventB.id}/payments`).set('Authorization', `Bearer ${userB.token}`).send({
    title: 'Payment B', amount: 10000, paidAt: '2030-02-01T10:00:00.000Z', method: 'cash',
  });
  assert.strictEqual(paymentBResponse.status, 201);

  for (const path of [`/api/clients/${clientA.id}`, `/api/events/${eventA.id}`]) {
    await expectStatus(request(app).get(path).set('Authorization', `Bearer ${userB.token}`));
    await expectStatus(request(app).put(path).set('Authorization', `Bearer ${userB.token}`).send({ title: 'IDOR' }));
    await expectStatus(request(app).delete(path).set('Authorization', `Bearer ${userB.token}`));
  }
  for (const path of [`/api/payments/${paymentA1.id}`, `/api/expenses/${expenseA.id}`, `/api/deliverables/${deliverableA.id}`]) {
    await expectStatus(request(app).get(path).set('Authorization', `Bearer ${userB.token}`));
    await expectStatus(request(app).put(path).set('Authorization', `Bearer ${userB.token}`).send({ title: 'IDOR' }));
    await expectStatus(request(app).delete(path).set('Authorization', `Bearer ${userB.token}`));
  }
  for (const child of ['payments', 'expenses', 'deliverables']) {
    await expectStatus(request(app).get(`/api/events/${eventA.id}/${child}`).set('Authorization', `Bearer ${userB.token}`));
  }
  await expectStatus(request(app).post(`/api/events/${eventA.id}/payments`).set('Authorization', `Bearer ${userB.token}`).send({ title: 'Cross', amount: 1, paidAt: '2030-01-01', method: 'cash' }));
  await expectStatus(request(app).post(`/api/events/${eventA.id}/expenses`).set('Authorization', `Bearer ${userB.token}`).send({ title: 'Cross', amount: 1, category: 'Other', incurredAt: '2030-01-01' }));
  await expectStatus(request(app).post(`/api/payments/${paymentA1.id}/proof`).set('Authorization', `Bearer ${userB.token}`).attach('proof', Buffer.from('not-an-image'), 'proof.png'));

  const aClients = await request(app).get('/api/clients').set('Authorization', `Bearer ${userA.token}`);
  const bClients = await request(app).get('/api/clients').set('Authorization', `Bearer ${userB.token}`);
  const aEvents = await request(app).get('/api/events').set('Authorization', `Bearer ${userA.token}`);
  const bEvents = await request(app).get('/api/events').set('Authorization', `Bearer ${userB.token}`);
  assert.deepStrictEqual(aClients.body.clients.map((item) => item.id), [clientA.id]);
  assert.deepStrictEqual(bClients.body.clients.map((item) => item.id), [clientB.id]);
  assert.deepStrictEqual(aEvents.body.events.map((item) => item.id), [eventA.id]);
  assert.deepStrictEqual(bEvents.body.events.map((item) => item.id), [eventB.id]);

  await mongoose.disconnect();
  const backend = spawn(process.execPath, ['src/server.js'], {
    cwd: require('path').join(__dirname, '..'),
    env: {
      ...process.env,
      PORT: '5011',
      NODE_ENV: 'test',
      MONGODB_URI: process.env.MONGODB_TEST_URI || 'mongodb://127.0.0.1:27017/lumen_studio_integration_test',
      JWT_SECRET: process.env.JWT_SECRET,
    },
    stdio: 'ignore',
  });
  try {
    await waitForHealth('http://127.0.0.1:5011/api/health');
    const loginA = await fetch('http://127.0.0.1:5011/api/auth/login', {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '9000000001', password: 'integration-password-123' }),
    });
    assert.strictEqual(loginA.status, 200);
    const loginBody = await loginA.json();
    const persisted = await fetch(`http://127.0.0.1:5011/api/events/${eventA.id}`, {
      headers: { Authorization: `Bearer ${loginBody.token}` },
    });
    assert.strictEqual(persisted.status, 200);
    const persistedBody = await persisted.json();
    assert.strictEqual(persistedBody.event.amountReceived, 50000);
    assert.strictEqual(persistedBody.event.totalExpenses, 15000);
    assert.strictEqual(persistedBody.event.deliverables[0].isCompleted, true);
    assert.ok(persistedBody.event.payments.some((payment) => payment.proof === proofUrl));
    const persistedPayment = await fetch(`http://127.0.0.1:5011/api/payments/${paymentA1.id}`, {
      headers: { Authorization: `Bearer ${loginBody.token}` },
    });
    assert.strictEqual(persistedPayment.status, 200);
    const persistedPaymentBody = await persistedPayment.json();
    assert.strictEqual(persistedPaymentBody.payment.proof, proofUrl);
  } finally {
    backend.kill();
  }

  console.log('LIVE_MONGODB_INTEGRATION_PASSED');
}

run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    if (mongoose.connection.readyState !== 0) await mongoose.disconnect();
  });
