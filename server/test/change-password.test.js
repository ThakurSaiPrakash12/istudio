const assert = require('assert');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

process.env.JWT_SECRET = 'test-secret-for-password-tests';

const memoryUsers = require('../src/store/memoryUsers');
const userRepository = require('../src/repositories/userRepository');
const { verifyCurrentPassword, changePassword } = require('../src/controllers/authController');

function mockResponse() {
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

async function runTests() {
  memoryUsers.enabled = true;

  const initialPassword = 'Password123!';
  const hashed = await bcrypt.hash(initialPassword, 12);
  const user = memoryUsers.create({
    username: 'photographer_alex',
    phone: '9876543210',
    password: hashed,
  });

  const userId = user._id || user.id;

  // 1. Verify with incorrect password
  {
    const req = {
      userId,
      body: { currentPassword: 'WrongPassword' },
    };
    const res = mockResponse();
    await verifyCurrentPassword(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Current password is incorrect.');
  }

  // 2. Verify with correct password
  {
    const req = {
      userId,
      body: { currentPassword: initialPassword },
    };
    const res = mockResponse();
    await verifyCurrentPassword(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.message, 'Current password verified.');
  }

  // 3. Change password with wrong current password
  {
    const req = {
      userId,
      body: { currentPassword: 'WrongPassword', newPassword: 'NewPassword456!' },
    };
    const res = mockResponse();
    await changePassword(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'Current password is incorrect.');
  }

  // 4. Change password with same new password as old password
  {
    const req = {
      userId,
      body: { currentPassword: initialPassword, newPassword: initialPassword },
    };
    const res = mockResponse();
    await changePassword(req, res);
    assert.strictEqual(res.statusCode, 400);
    assert.strictEqual(res.body.success, false);
    assert.strictEqual(res.body.message, 'New password cannot be the same as your current password.');
  }

  // 5. Change password successfully
  {
    const newPassword = 'BrandNewPassword999!';
    const req = {
      userId,
      body: { currentPassword: initialPassword, newPassword },
    };
    const res = mockResponse();
    await changePassword(req, res);
    assert.strictEqual(res.statusCode, 200);
    assert.strictEqual(res.body.success, true);
    assert.strictEqual(res.body.message, 'Password changed successfully.');

    // Verify user can now authenticate with the new password
    const updatedUser = await userRepository.findById(userId, { withPassword: true });
    const matchesNew = await bcrypt.compare(newPassword, updatedUser.password);
    assert.strictEqual(matchesNew, true);

    const matchesOld = await bcrypt.compare(initialPassword, updatedUser.password);
    assert.strictEqual(matchesOld, false);
  }

  console.log('change-password tests passed successfully!');
}

runTests().catch((err) => {
  console.error('Test failed:', err);
  process.exit(1);
});
