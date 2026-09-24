const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

// In-memory store for OTP tracking (for clustered environments, Redis can be used)
const otpStore = new Map();

const OTP_TTL_MS = 5 * 60 * 1000; // 5 minutes
const RESEND_COOLDOWN_MS = 60 * 1000; // 60 seconds
const MAX_ATTEMPTS = 5;

/**
 * Generate cryptographically secure 6-digit numeric OTP
 */
function generateNumericOtp() {
  return String(crypto.randomInt(100000, 1000000));
}

async function dispatchSms(phone, otp) {
  const provider = (process.env.SMS_PROVIDER || '').toLowerCase();

  if (provider === 'fast2sms' && process.env.FAST2SMS_API_KEY) {
    try {
      const response = await fetch('https://www.fast2sms.com/dev/bulkV2', {
        method: 'POST',
        headers: {
          authorization: process.env.FAST2SMS_API_KEY,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          variables_values: otp,
          route: 'otp',
          numbers: phone,
        }),
      });
      const data = await response.json();
      console.log(`[Fast2SMS] Dispatched to ${phone}:`, data);
      return true;
    } catch (e) {
      console.error('[Fast2SMS] Failed to send SMS:', e.message);
      return false;
    }
  }

  if (
    provider === 'twilio' &&
    process.env.TWILIO_ACCOUNT_SID &&
    process.env.TWILIO_AUTH_TOKEN
  ) {
    try {
      const twilioAuth = Buffer.from(
        `${process.env.TWILIO_ACCOUNT_SID}:${process.env.TWILIO_AUTH_TOKEN}`,
      ).toString('base64');
      const params = new URLSearchParams();
      params.append('To', phone.startsWith('+') ? phone : `+91${phone}`);
      params.append('From', process.env.TWILIO_PHONE_NUMBER || '');
      params.append('Body', `Your Studio verification code is: ${otp}. Valid for 5 minutes.`);

      const response = await fetch(
        `https://api.twilio.com/2010-04-01/Accounts/${process.env.TWILIO_ACCOUNT_SID}/Messages.json`,
        {
          method: 'POST',
          headers: {
            Authorization: `Basic ${twilioAuth}`,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: params.toString(),
        },
      );
      const data = await response.json();
      console.log(`[Twilio] Dispatched to ${phone}:`, data?.sid || data);
      return true;
    } catch (e) {
      console.error('[Twilio] Failed to send SMS:', e.message);
      return false;
    }
  }

  console.log(`\n======================================================`);
  console.log(`[SMS DISPATCH] Recipient: +91 ${phone}`);
  console.log(`[SMS DISPATCH] Studio Verification OTP: [ ${otp} ]`);
  console.log(`======================================================\n`);
  return false;
}

/**
 * Send or generate OTP for phone verification
 */
async function generateAndSendOtp(phone) {
  const now = Date.now();
  const existing = otpStore.get(phone);

  if (existing && now - existing.lastSentAt < RESEND_COOLDOWN_MS) {
    const remainingSeconds = Math.ceil(
      (RESEND_COOLDOWN_MS - (now - existing.lastSentAt)) / 1000,
    );
    const err = new Error(
      `Please wait ${remainingSeconds}s before requesting another OTP.`,
    );
    err.statusCode = 429;
    throw err;
  }

  const rawOtp = generateNumericOtp();
  const hashedOtp = await bcrypt.hash(rawOtp, 8);

  otpStore.set(phone, {
    hashedOtp,
    expiresAt: now + OTP_TTL_MS,
    lastSentAt: now,
    attempts: 0,
  });

  const smsSent = await dispatchSms(phone, rawOtp);

  return {
    success: true,
    message: smsSent
        ? 'Verification code sent to your mobile number via SMS.'
        : 'Verification code generated.',
    cooldownSeconds: 60,
    debugOtp: rawOtp,
  };
}

/**
 * Verify user supplied OTP and issue a one-time 10-minute password reset token
 */
async function verifyOtpAndIssueResetToken(phone, inputOtp) {
  const now = Date.now();
  const record = otpStore.get(phone);

  if (!record) {
    const err = new Error('No active OTP request found. Please request a new code.');
    err.statusCode = 400;
    throw err;
  }

  if (now > record.expiresAt) {
    otpStore.delete(phone);
    const err = new Error('This OTP has expired. Please request a new code.');
    err.statusCode = 400;
    throw err;
  }

  if (record.attempts >= MAX_ATTEMPTS) {
    otpStore.delete(phone);
    const err = new Error('Too many incorrect attempts. Please request a new code.');
    err.statusCode = 429;
    throw err;
  }

  const isValid = await bcrypt.compare(String(inputOtp).trim(), record.hashedOtp);
  if (!isValid) {
    record.attempts += 1;
    const remaining = MAX_ATTEMPTS - record.attempts;
    const err = new Error(
      remaining > 0
          ? `Incorrect OTP. ${remaining} attempt(s) remaining.`
          : 'Incorrect OTP. Please request a new code.',
    );
    err.statusCode = 400;
    throw err;
  }

  // OTP is valid - invalidate it immediately
  otpStore.delete(phone);

  // Generate a signed one-time reset token valid for 10 minutes
  const resetToken = jwt.sign(
    {
      phone,
      purpose: 'password_reset',
    },
    process.env.JWT_SECRET || 'lumen_studio_fallback_secret',
    { expiresIn: '10m', algorithm: 'HS256' },
  );

  return {
    success: true,
    resetToken,
    message: 'OTP verified successfully.',
  };
}

/**
 * Verify the reset token before allowing password change
 */
function verifyResetToken(resetToken) {
  try {
    const payload = jwt.verify(
      resetToken,
      process.env.JWT_SECRET || 'lumen_studio_fallback_secret',
      { algorithms: ['HS256'] },
    );

    if (payload.purpose !== 'password_reset' || !payload.phone) {
      throw new Error('Invalid token purpose');
    }

    return payload.phone;
  } catch (_) {
    const err = new Error('Invalid or expired password reset session. Please try again.');
    err.statusCode = 401;
    throw err;
  }
}

/**
 * Verify OTP directly for phone verification flows (like signup)
 */
async function verifyOtpForPhone(phone, inputOtp) {
  const now = Date.now();
  const record = otpStore.get(phone);

  if (!record) {
    const err = new Error('No active verification code found. Please request a new code.');
    err.statusCode = 400;
    throw err;
  }

  if (now > record.expiresAt) {
    otpStore.delete(phone);
    const err = new Error('This verification code has expired. Please request a new code.');
    err.statusCode = 400;
    throw err;
  }

  if (record.attempts >= MAX_ATTEMPTS) {
    otpStore.delete(phone);
    const err = new Error('Too many incorrect attempts. Please request a new code.');
    err.statusCode = 429;
    throw err;
  }

  const isValid = await bcrypt.compare(String(inputOtp).trim(), record.hashedOtp);
  if (!isValid) {
    record.attempts += 1;
    const remaining = MAX_ATTEMPTS - record.attempts;
    const err = new Error(
      remaining > 0
          ? `Incorrect verification code. ${remaining} attempt(s) remaining.`
          : 'Incorrect verification code. Please request a new code.',
    );
    err.statusCode = 400;
    throw err;
  }

  // Code is verified - invalidate
  otpStore.delete(phone);
  return true;
}

module.exports = {
  generateAndSendOtp,
  verifyOtpAndIssueResetToken,
  verifyResetToken,
  verifyOtpForPhone,
};
