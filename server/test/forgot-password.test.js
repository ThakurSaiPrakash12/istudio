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
  // Test 7: Verify Username directly without OTP
  const authController = require('../src/controllers/authController');
  
  // 7a. Non-existent username
  let mockRes = {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    json(data) { this.data = data; return this; }
  };
  await authController.forgotPasswordVerifyUsername({ body: { username: 'non_existent_studio_xyz' } }, mockRes);
  assert.strictEqual(mockRes.statusCode, 404);
  console.log('✓ Non-existent username correctly rejected (404)');

  // 7b. Existing username verification
  mockRes = {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    json(data) { this.data = data; return this; }
  };
  await authController.forgotPasswordVerifyUsername({ body: { username: 'test_photographer' } }, mockRes);
  assert.strictEqual(mockRes.data.success, true);
  assert.strictEqual(mockRes.data.username, 'test_photographer');
  assert(mockRes.data.resetToken, 'Should return reset token');
  console.log('✓ Existing username verified without OTP');

  // 7c. Reset password using username directly
  const finalPassword = 'DirectPassword789';
  mockRes = {
    statusCode: 200,
    status(code) { this.statusCode = code; return this; },
    json(data) { this.data = data; return this; }
  };
  await authController.forgotPasswordReset({
    body: {
      username: 'test_photographer',
      newPassword: finalPassword,
    }
  }, mockRes);
  assert.strictEqual(mockRes.data.success, true);

  const finalUser = await userRepository.findByUsername('test_photographer');
  const userWithPw = await userRepository.findByPhone(finalUser.phone, { withPassword: true });
  const isFinalMatch = await bcrypt.compare(finalPassword, userWithPw.password);
  assert.strictEqual(isFinalMatch, true, 'User password reset via username succeeds');
  console.log('✓ Password reset directly via username verified');

  console.log('All backend Forgot Password tests passed successfully!');
}

runTests().catch((err) => {
  console.error('Test failed:', err);
  process.exit(1);
});
