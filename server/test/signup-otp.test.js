const assert = require('assert');
process.env.JWT_SECRET = 'test-secret-signup-otp';
process.env.NODE_ENV = 'test';

const otpService = require('../src/services/otpService');
const userRepository = require('../src/repositories/userRepository');
const memoryUsers = require('../src/store/memoryUsers');
const bcrypt = require('bcryptjs');

async function runTests() {
  console.log('--- Running Signup Phone OTP Verification Tests ---');
  memoryUsers.enabled = true;

  const testPhone = '9123456789';
  const testUsername = 'new_studio_owner';
  const testPassword = 'StrongPassword123';

  // Test 1: Send OTP for signup
  const sendRes = await otpService.generateAndSendOtp(testPhone);
  assert.strictEqual(sendRes.success, true);
  assert(sendRes.debugOtp, 'Should include debugOtp in test mode');
  console.log('✓ Signup OTP dispatched successfully');

  // Test 2: Reject invalid OTP
  try {
    await otpService.verifyOtpForPhone(testPhone, '999999');
    assert.fail('Should fail on wrong OTP');
  } catch (err) {
    assert.strictEqual(err.statusCode, 400);
    console.log('✓ Invalid signup OTP correctly rejected');
  }

  // Test 3: Verify correct OTP
  const isVerified = await otpService.verifyOtpForPhone(testPhone, sendRes.debugOtp);
  assert.strictEqual(isVerified, true);
  console.log('✓ Signup OTP successfully verified');

  // Test 4: Create user after verification
  const hashedPassword = await bcrypt.hash(testPassword, 12);
  const user = await userRepository.createUser({
    username: testUsername,
    phone: testPhone,
    password: hashedPassword,
  });
  assert(user, 'User should be created');
  assert.strictEqual(user.phone, testPhone);
  assert.strictEqual(user.username, testUsername);
  console.log('✓ Verified user account successfully created');

  console.log('All signup OTP tests passed!');
}

runTests().catch((err) => {
  console.error('Test failed:', err);
  process.exit(1);
});
