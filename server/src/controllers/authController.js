const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { validationResult } = require('express-validator');

const userRepository = require('../repositories/userRepository');
const otpService = require('../services/otpService');
const { uploadToCloudinary } = require('../config/cloudinary');
const logger = require('../config/logger');

function logCaught(req, message, error) {
  const meta = logger.fromRequest(req, error);
  if ((error && error.statusCode) && error.statusCode < 500) {
    logger.warn(message, meta);
    return;
  }
  logger.error(message, meta);
}

function normalizePhone(value = '') {
  let digits = String(value).replace(/\D/g, '');
  if (digits.startsWith('91') && digits.length === 12) {
    digits = digits.slice(2);
  }
  if (digits.startsWith('0') && digits.length === 11) {
    digits = digits.slice(1);
  }
  return digits;
}

function signToken(user) {
  return jwt.sign(
    {
      id: user._id.toString(),
      username: user.username,
      phone: user.phone,
    },
    process.env.JWT_SECRET,
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d', algorithm: 'HS256' },
  );
}

function sendValidationError(req, res) {
  const errors = validationResult(req);
  if (errors.isEmpty()) return false;

  return res.status(400).json({
    success: false,
    message: errors.array()[0].msg,
  });
}

async function signup(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const username = String(req.body.username || '').trim();
    const phone = normalizePhone(req.body.phone);
    const password = String(req.body.password || '');

    const existingPhone = await userRepository.findByPhone(phone);
    if (existingPhone) {
      return res.status(409).json({
        success: false,
        message: 'An account with this phone number already exists.',
      });
    }

    const existingUsername = await userRepository.findByUsername(username);
    if (existingUsername) {
      return res.status(409).json({
        success: false,
        message: 'That username is already taken.',
      });
    }

    const hashedPassword = await bcrypt.hash(password, 12);
    const user = await userRepository.createUser({
      username,
      phone,
      password: hashedPassword,
    });

    return res.status(201).json({
      success: true,
      token: signToken(user),
      user: user.toPublicJSON(),
    });
  } catch (error) {
    logCaught(req, 'Signup error', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to create your account right now.',
    });
  }
}

async function login(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const phone = normalizePhone(req.body.phone);
    const password = String(req.body.password || '');

    const user = await userRepository.findByPhone(phone, { withPassword: true });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Phone number or password is incorrect.',
      });
    }

    const matches = await bcrypt.compare(password, user.password);
    if (!matches) {
      return res.status(401).json({
        success: false,
        message: 'Phone number or password is incorrect.',
      });
    }

    return res.json({
      success: true,
      token: signToken(user),
      user: user.toPublicJSON(),
    });
  } catch (error) {
    logCaught(req, 'Login error', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to sign in right now.',
    });
  }
}

async function me(req, res) {
  try {
    const user = await userRepository.findById(req.userId);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Your session is no longer valid.',
      });
    }

    return res.json({
      success: true,
      user: user.toPublicJSON(),
    });
  } catch (error) {
    logCaught(req, 'Session error', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to restore your session.',
    });
  }
}

const PROFILE_FIELDS = [
  'studioName',
  'ownerName',
  'email',
  'city',
  'address',
  'about',
  'instagram',
  'youtube',
  'website',
  'specialties',
  'logoUrl',
];

function validateProfileFields(fields) {
  const textFields = PROFILE_FIELDS.filter((key) => key !== 'logoUrl');
  for (const key of textFields) {
    if (fields[key] !== undefined && String(fields[key]).length > 240) {
      return `${key} is too long.`;
    }
  }
  if (fields.email && !/^\S+@\S+\.\S+$/.test(fields.email)) {
    return 'Enter a valid email address.';
  }
  for (const key of ['website', 'instagram', 'youtube']) {
    if (fields[key]) {
      try {
        const url = new URL(fields[key].startsWith('http') ? fields[key] : `https://${fields[key]}`);
        if (!['http:', 'https:'].includes(url.protocol)) return `Enter a valid ${key} URL.`;
      } catch (_) {
        return `Enter a valid ${key} URL.`;
      }
    }
  }
  if (fields.logoUrl && (!fields.logoUrl.startsWith('https://') || !fields.logoUrl.includes('cloudinary.com'))) {
    return 'Profile images must be hosted securely.';
  }
  return null;
}

async function updateProfile(req, res) {
  try {
    const fields = {};
    for (const key of PROFILE_FIELDS) {
      if (req.body[key] !== undefined) {
        fields[key] = String(req.body[key] || '').trim();
      }
    }
    if (req.body.phone) {
      const phone = normalizePhone(req.body.phone);
      if (phone.length !== 10) {
        return res.status(400).json({
          success: false,
          message: 'Enter a valid 10-digit phone number',
        });
      }
      const existing = await userRepository.findByPhone(phone);
      if (existing && existing._id.toString() !== req.userId) {
        return res.status(409).json({
          success: false,
          message: 'That phone number is already in use.',
        });
      }
      fields.phone = phone;
    }
    const validationMessage = validateProfileFields(fields);
    if (validationMessage) {
      return res.status(400).json({ success: false, message: validationMessage });
    }

    const user = await userRepository.updateUser(req.userId, fields);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Profile not found.',
      });
    }

    return res.json({
      success: true,
      user: user.toPublicJSON(),
    });
  } catch (error) {
    logCaught(req, 'Update profile error', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to update your profile right now.',
    });
  }
}

async function uploadLogo(req, res) {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'Choose a profile image or studio logo to upload.',
      });
    }

    // 1. Upload file strictly to Cloudinary CDN
    const cloudinaryResult = await uploadToCloudinary(req.file.path, {
      folder: 'lumen_studio/profiles',
    });

    let logoUrl = cloudinaryResult.secure_url || cloudinaryResult.url || '';
    if (logoUrl.startsWith('http://')) {
      logoUrl = `https://${logoUrl.substring(7)}`;
    }

    if (!logoUrl.startsWith('https://')) {
      return res.status(500).json({
        success: false,
        message: 'Cloudinary did not return a valid HTTPS image URL.',
      });
    }

    // 2. Save ONLY the Cloudinary HTTPS URL in MongoDB (no base64 / binary stored in database)
    const user = await userRepository.updateUser(req.userId, { logoUrl });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Profile not found.',
      });
    }

    return res.json({
      success: true,
      imageUrl: logoUrl,
      user: user.toPublicJSON(),
    });
  } catch (error) {
    logCaught(req, 'Logo upload error', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to upload your profile image right now.',
    });
  }
}

async function forgotPasswordSendOtp(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const phone = normalizePhone(req.body.phone);
    const user = await userRepository.findByPhone(phone);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'No registered studio account found with this phone number.',
      });
    }

    const result = await otpService.generateAndSendOtp(phone);
    return res.json(result);
  } catch (error) {
    logCaught(req, 'forgotPasswordSendOtp error', error);
    const status = error.statusCode || 500;
    return res.status(status).json({
      success: false,
      message: error.message || 'Unable to send OTP at this time.',
    });
  }
}

async function forgotPasswordVerifyOtp(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const phone = normalizePhone(req.body.phone);
    const otp = String(req.body.otp || '').trim();

    const result = await otpService.verifyOtpAndIssueResetToken(phone, otp);
    return res.json(result);
  } catch (error) {
    logCaught(req, 'forgotPasswordVerifyOtp error', error);
    const status = error.statusCode || 400;
    return res.status(status).json({
      success: false,
      message: error.message || 'Unable to verify OTP.',
    });
  }
}

async function forgotPasswordVerifyUsername(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const username = String(req.body.username || '').trim();
    const user = await userRepository.findByUsername(username);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: `No studio account found with username "${username}".`,
      });
    }

    const resetToken = jwt.sign(
      {
        id: (user._id || user.id).toString(),
        username: user.username,
        action: 'reset_password',
      },
      process.env.JWT_SECRET,
      { expiresIn: '15m' },
    );

    const phone = user.phone || '';
    const maskedPhone =
      phone.length >= 4
        ? '•'.repeat(Math.max(0, phone.length - 4)) + phone.slice(-4)
        : phone;

    return res.json({
      success: true,
      message: 'Account verified successfully.',
      username: user.username,
      maskedPhone,
      resetToken,
    });
  } catch (error) {
    logCaught(req, 'forgotPasswordVerifyUsername error', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to verify username right now.',
    });
  }
}

async function forgotPasswordReset(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const username = String(req.body.username || '').trim();
    const resetToken = String(req.body.resetToken || '').trim();
    const newPassword = String(req.body.newPassword || '');

    let user;

    // 1. Try finding user directly by username if provided
    if (username) {
      user = await userRepository.findByUsername(username);
    }

    // 2. Try validating signed JWT resetToken if user not found yet
    if (!user && resetToken) {
      try {
        const decoded = jwt.verify(resetToken, process.env.JWT_SECRET);
        if (decoded.id) {
          user = await userRepository.findById(decoded.id);
        } else if (decoded.username) {
          user = await userRepository.findByUsername(decoded.username);
        }
      } catch (_) {
        // Fallback to legacy token decode
      }
    }

    // 3. Try legacy OTP resetToken (stores phone in otpStore)
    if (!user && resetToken) {
      try {
        const phone = otpService.verifyResetToken(resetToken);
        if (phone) {
          user = await userRepository.findByPhone(phone);
        }
      } catch (_) {}
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Account not found. Please verify your username again.',
      });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 12);
    await userRepository.updateUser(user._id || user.id, { password: hashedPassword });

    return res.json({
      success: true,
      message: 'Password reset successfully. You can now sign in with your new password.',
    });
  } catch (error) {
    logCaught(req, 'forgotPasswordReset error', error);
    const status = error.statusCode || 500;
    return res.status(status).json({
      success: false,
      message: error.message || 'Unable to reset password.',
    });
  }
}

async function signupSendOtp(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const username = String(req.body.username || '').trim();
    const phone = normalizePhone(req.body.phone);

    const existingPhone = await userRepository.findByPhone(phone);
    if (existingPhone) {
      return res.status(409).json({
        success: false,
        message: 'An account with this phone number already exists.',
      });
    }

    const existingUsername = await userRepository.findByUsername(username);
    if (existingUsername) {
      return res.status(409).json({
        success: false,
        message: 'That username is already taken.',
      });
    }

    const result = await otpService.generateAndSendOtp(phone);
    return res.json(result);
  } catch (error) {
    logCaught(req, 'signupSendOtp error', error);
    const status = error.statusCode || 500;
    return res.status(status).json({
      success: false,
      message: error.message || 'Unable to send signup verification code.',
    });
  }
}

async function signupVerify(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const username = String(req.body.username || '').trim();
    const phone = normalizePhone(req.body.phone);
    const password = String(req.body.password || '');
    const otp = String(req.body.otp || '').trim();

    const existingPhone = await userRepository.findByPhone(phone);
    if (existingPhone) {
      return res.status(409).json({
        success: false,
        message: 'An account with this phone number already exists.',
      });
    }

    const existingUsername = await userRepository.findByUsername(username);
    if (existingUsername) {
      return res.status(409).json({
        success: false,
        message: 'That username is already taken.',
      });
    }

    // Verify OTP
    await otpService.verifyOtpForPhone(phone, otp);

    const hashedPassword = await bcrypt.hash(password, 12);
    const user = await userRepository.createUser({
      username,
      phone,
      password: hashedPassword,
    });

    return res.status(201).json({
      success: true,
      token: signToken(user),
      user: user.toPublicJSON(),
    });
  } catch (error) {
    logCaught(req, 'signupVerify error', error);
    const status = error.statusCode || 400;
    return res.status(status).json({
      success: false,
      message: error.message || 'Unable to verify code and complete signup.',
    });
  }
}

async function verifyCurrentPassword(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const currentPassword = String(req.body.currentPassword || '');
    const user = await userRepository.findById(req.userId, { withPassword: true });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Account not found.',
      });
    }

    const matches = await bcrypt.compare(currentPassword, user.password);
    if (!matches) {
      return res.status(400).json({
        success: false,
        message: 'Current password is incorrect.',
      });
    }

    return res.json({
      success: true,
      message: 'Current password verified.',
    });
  } catch (error) {
    logCaught(req, 'verifyCurrentPassword error', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to verify password right now.',
    });
  }
}

async function changePassword(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const currentPassword = String(req.body.currentPassword || '');
    const newPassword = String(req.body.newPassword || '');

    const user = await userRepository.findById(req.userId, { withPassword: true });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Account not found.',
      });
    }

    const matches = await bcrypt.compare(currentPassword, user.password);
    if (!matches) {
      return res.status(400).json({
        success: false,
        message: 'Current password is incorrect.',
      });
    }

    if (currentPassword === newPassword) {
      return res.status(400).json({
        success: false,
        message: 'New password cannot be the same as your current password.',
      });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 12);
    await userRepository.updateUser(user._id || user.id, { password: hashedPassword });

    return res.json({
      success: true,
      message: 'Password changed successfully.',
    });
  } catch (error) {
    logCaught(req, 'changePassword error', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to update password right now.',
    });
  }
}

module.exports = {
  signup,
  signupSendOtp,
  signupVerify,
  login,
  me,
  updateProfile,
  uploadLogo,
  normalizePhone,
  forgotPasswordSendOtp,
  forgotPasswordVerifyOtp,
  forgotPasswordReset,
  forgotPasswordVerifyUsername,
  verifyCurrentPassword,
  changePassword,
};
