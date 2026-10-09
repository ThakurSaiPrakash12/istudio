'use strict';

const assert = require('node:assert/strict');
const { describe, it, before } = require('node:test');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

process.env.DATA_ENCRYPTION_KEY = 'd7a9f8b4c2e105829374650192837465f1e2d3c4b5a697887766554433221100';
process.env.JWT_SECRET = 'test-jwt-secret-key-32chars-min!!';

const userRepository = require('../src/repositories/userRepository');
const memoryUsers = require('../src/store/memoryUsers');
const otpService = require('../src/services/otpService');
const emailService = require('../src/services/emailService');
const authController = require('../src/controllers/authController');

function createMockRes() {
  const res = {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(payload) {
      this.body = payload;
      return this;
    },
  };
  return res;
}

describe('Delete Account Verification & Deletion Flow', () => {
  before(() => {
    memoryUsers.enabled = true;
  });

  it('checks OTP first to issue deleteToken, then validates password to delete account', async () => {
    const rawPassword = 'SecurePassword123!';
    const hashedPassword = await bcrypt.hash(rawPassword, 10);
    const email = `del_${Date.now()}@photostudio.com`;
    const username = `deluser_${Date.now()}`;

    const user = await userRepository.createUser({
      username,
      email,
      phone: '9876543210',
      password: hashedPassword,
    });

    let sentOtp;
    const originalSend = emailService.sendVerificationEmail;
    emailService.sendVerificationEmail = async ({ otp }) => {
      sentOtp = otp;
      return { sent: true };
    };

    try {
      // 1. Send delete account OTP
      const sendReq = { userId: user._id.toString() };
      const sendRes = createMockRes();
      await authController.deleteAccountSendOtp(sendReq, sendRes);

      assert.equal(sendRes.statusCode, 200);
      assert.equal(sendRes.body.success, true);
      assert.ok(sentOtp, 'OTP was sent');

      // 2. Checking invalid OTP fails (like signup OTP check)
      const wrongOtpReq = {
        userId: user._id.toString(),
        body: { otp: '000000' },
      };
      const wrongOtpRes = createMockRes();
      await authController.deleteAccountVerifyOtp(wrongOtpReq, wrongOtpRes);
      assert.equal(wrongOtpRes.statusCode, 400);
      assert.equal(wrongOtpRes.body.success, false);

      // 3. Checking valid OTP succeeds and returns deleteToken
      const verifyReq = {
        userId: user._id.toString(),
        body: { otp: sentOtp },
      };
      const verifyRes = createMockRes();
      await authController.deleteAccountVerifyOtp(verifyReq, verifyRes);

      assert.equal(verifyRes.statusCode, 200);
      assert.equal(verifyRes.body.success, true);
      assert.ok(verifyRes.body.deleteToken, 'deleteToken was issued');

      const deleteToken = verifyRes.body.deleteToken;

      // 4. Entering wrong password in step 2 fails
      const wrongPassReq = {
        userId: user._id.toString(),
        body: {
          deleteToken,
          password: 'WrongPassword!',
        },
      };
      const wrongPassRes = createMockRes();
      await authController.deleteAccount(wrongPassReq, wrongPassRes);
      assert.equal(wrongPassRes.statusCode, 400);
      assert.equal(wrongPassRes.body.success, false);
      assert.match(wrongPassRes.body.message, /Incorrect password/i);

      // 5. Entering correct password in step 2 deletes the account
      const correctPassReq = {
        userId: user._id.toString(),
        body: {
          deleteToken,
          password: rawPassword,
        },
      };
      const correctPassRes = createMockRes();
      await authController.deleteAccount(correctPassReq, correctPassRes);

      assert.equal(correctPassRes.statusCode, 200);
      assert.equal(correctPassRes.body.success, true);

      // User account is now deleted
      const checkUser = await userRepository.findById(user._id.toString());
      assert.equal(checkUser, null);
    } finally {
      emailService.sendVerificationEmail = originalSend;
    }
  });
});
