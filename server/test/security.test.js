const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'test-secret-for-security-tests';

const { requireAuth } = require('../src/middleware/auth');
const { hasSupportedImageSignature } = require('../src/middleware/upload');
const { connectDb } = require('../src/config/db');
const memoryInvoices = require('../src/store/memoryInvoices');
const { invoiceTotals } = require('../src/models/Invoice');

function response() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

const unauthorized = response();
let called = false;
requireAuth(
  { headers: { authorization: 'Basic token' } },
  unauthorized,
  () => { called = true; },
);
assert.strictEqual(unauthorized.statusCode, 401);
assert.strictEqual(called, false);

const token = jwt.sign({ id: 'user-a' }, process.env.JWT_SECRET, { algorithm: 'HS256' });
const authorized = response();
const authenticatedRequest = {
  headers: { authorization: `Bearer ${token}` },
};
let authenticatedUser;
requireAuth(
  authenticatedRequest,
  authorized,
  () => { authenticatedUser = authenticatedRequest.userId; },
);
assert.strictEqual(authenticatedUser, 'user-a');

const invoice = memoryInvoices.create({
  userId: 'user-a',
  eventName: 'Private event',
  contactName: 'Client',
  phone: '9876543210',
  address: 'Address',
  dueDate: new Date('2099-01-01'),
  deliverables: [{ name: 'Coverage', cost: 1000 }],
});
assert.strictEqual(memoryInvoices.listByUser('user-b').length, 0);
assert.strictEqual(memoryInvoices.findByIdForUser(invoice.id, 'user-b'), null);
assert.strictEqual(memoryInvoices.update(invoice.id, 'user-b', { eventName: 'Stolen' }), null);
assert.strictEqual(memoryInvoices.remove(invoice.id, 'user-b'), false);
assert.strictEqual(invoiceTotals(invoice.deliverables, 1000).received, 1000);

const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'lumen-security-'));
const validPng = path.join(tempDir, 'valid.png');
const invalidImage = path.join(tempDir, 'invalid.png');
fs.writeFileSync(validPng, Buffer.from('\x89PNG\r\n\x1a\n' + '123456', 'binary'));
fs.writeFileSync(invalidImage, Buffer.from('<script>alert(1)</script>'));
assert.strictEqual(hasSupportedImageSignature(validPng), true);
assert.strictEqual(hasSupportedImageSignature(invalidImage), false);
fs.rmSync(tempDir, { recursive: true, force: true });

process.env.NODE_ENV = 'production';
delete process.env.MONGODB_URI;
assert.rejects(connectDb(), /MONGODB_URI is required in production/)
  .then(() => console.log('security checks passed'))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
