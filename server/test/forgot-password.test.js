const assert = require('assert');
process.env.JWT_SECRET = 'test-secret-forgot-password';
process.env.NODE_ENV = 'test';

const otpService = require('../src/services/otpService');
const userRepository = require('../src/repositories/userRepository');
const memoryUsers = require('../src/store/memoryUsers');
const bcrypt = require('bcryptjs');

async function runTests() {
  console.log('--- Running Forgot Password & OTP Backend Tests ---');
  memoryUsers.enabled = true;

  const testPhone = '9876543210';
  const initialPassword = 'InitialPassword123';
  const newPassword = 'NewSecurePassword456';

  // Seed user
  const hashedPassword = await bcrypt.hash(initialPassword, 12);
  const createdUser = await userRepository.createUser({
    username: 'test_photographer',
    phone: testPhone,
    password: hashedPassword,
  });
  assert(createdUser, 'User should be created');

  // Test 1: Send OTP
  const sendRes = await otpService.generateAndSendOtp(testPhone);
  assert.strictEqual(sendRes.success, true);
  assert(sendRes.debugOtp, 'Should include debugOtp in test mode');
  assert.strictEqual(sendRes.debugOtp.length, 6);
  console.log('✓ OTP generated and dispatched successfully');

  // Test 2: Rate limit cooldown (< 60s)
  try {
    await otpService.generateAndSendOtp(testPhone);
    assert.fail('Should have thrown rate limit 429');
  } catch (err) {
    assert.strictEqual(err.statusCode, 429);
    console.log('✓ Rate limit cooldown enforced (429)');
  }

  // Test 3: Incorrect OTP verification
  try {
    await otpService.verifyOtpAndIssueResetToken(testPhone, '000000');
    assert.fail('Should have rejected incorrect OTP');
  } catch (err) {
    assert.strictEqual(err.statusCode, 400);
    console.log('✓ Incorrect OTP rejected');
  }

  // Test 4: Correct OTP verification & Reset Token issuance
  const verifyRes = await otpService.verifyOtpAndIssueResetToken(testPhone, sendRes.debugOtp);
  assert.strictEqual(verifyRes.success, true);
  assert(verifyRes.resetToken, 'Should return signed reset token');
  console.log('✓ Correct OTP verified and reset token issued');

  // Test 5: Verify reset token
  const verifiedPhone = otpService.verifyResetToken(verifyRes.resetToken);
  assert.strictEqual(verifiedPhone, testPhone);
  console.log('✓ Reset token successfully validated');

  // Test 6: Reset user password
  const newHashed = await bcrypt.hash(newPassword, 12);
  await userRepository.updateUser(createdUser.id || createdUser._id, { password: newHashed });

  const updatedUser = await userRepository.findByPhone(testPhone, { withPassword: true });
  const isMatch = await bcrypt.compare(newPassword, updatedUser.password);
  assert.strictEqual(isMatch, true, 'User should authenticate with new password');
  console.log('✓ Password reset persisted and verified');

  console.log('All backend Forgot Password & OTP tests passed successfully!');
}

runTests().catch((err) => {
  console.error('Test failed:', err);
  process.exit(1);
});
