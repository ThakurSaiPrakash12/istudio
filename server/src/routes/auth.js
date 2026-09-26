const express = require('express');
const { body } = require('express-validator');

const {
  login,
  googleAuth,
  me,
  signup,
  signupSendOtp,
  signupVerify,
  updateProfile,
  uploadLogo,
  normalizePhone,
  forgotPasswordSendOtp,
  forgotPasswordVerifyOtp,
  forgotPasswordReset,
  forgotPasswordVerifyUsername,
  verifyCurrentPassword,
  changePassword,
} = require('../controllers/authController');
const { requireAuth } = require('../middleware/auth');
const {
  uploadLogo: logoUpload,
  hasSupportedImageSignature,
} = require('../middleware/upload');
const fs = require('fs');

const router = express.Router();

const phoneRule = body('phone')
  .customSanitizer(normalizePhone)
  .isLength({ min: 10, max: 10 })
  .withMessage('Enter a valid 10-digit phone number')
  .isNumeric()
  .withMessage('Enter a valid 10-digit phone number');

const usernameRule = body('username')
  .trim()
  .isLength({ min: 3, max: 24 })
  .withMessage('Username must be 3-24 characters')
  .matches(/^[A-Za-z0-9_]+$/)
  .withMessage('Username can only include letters, numbers, and underscores');

const passwordRule = body('password')
  .isLength({ min: 8 })
  .withMessage('Password must be at least 8 characters');

const otpRule = body('otp')
  .trim()
  .isLength({ min: 6, max: 6 })
  .withMessage('Enter the 6-digit verification code')
  .isNumeric()
  .withMessage('OTP must be numbers only');

router.post(
  '/signup',
  [usernameRule, phoneRule, passwordRule],
  signup,
);

router.post(
  '/signup/send-otp',
  [usernameRule, phoneRule],
  signupSendOtp,
);

router.post(
  '/signup/verify',
  [usernameRule, phoneRule, passwordRule, otpRule],
  signupVerify,
);

router.post(
  '/login',
  [
    phoneRule,
    body('password').notEmpty().withMessage('Enter your password'),
  ],
  login,
);

router.post(
  '/google',
  googleAuth,
);

router.post(
  '/forgot-password/verify-username',
  [usernameRule],
  forgotPasswordVerifyUsername,
);

router.post(
  '/forgot-password/send-otp',
  [phoneRule],
  forgotPasswordSendOtp,
);

router.post(
  '/forgot-password/verify-otp',
  [
    phoneRule,
    body('otp')
      .trim()
      .isLength({ min: 6, max: 6 })
      .withMessage('Enter the 6-digit verification code')
      .isNumeric()
      .withMessage('OTP must be numbers only'),
  ],
  forgotPasswordVerifyOtp,
);

router.post(
  '/forgot-password/reset',
  [
    body('username').custom((val, { req }) => {
      if (!val && !req.body.resetToken) {
        throw new Error('Username or verification session is required');
      }
      return true;
    }),
    body('newPassword')
      .isLength({ min: 8 })
      .withMessage('Password must be at least 8 characters'),
  ],
  forgotPasswordReset,
);

function handleLogoUpload(req, res, next) {
  logoUpload(req, res, (err) => {
    if (err) {
      return res.status(400).json({
        success: false,
        message: err.message || 'Please upload a valid image.',
      });
    }
    if (!req.file || !hasSupportedImageSignature(req.file.path)) {
      if (req.file?.path && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({
        success: false,
        message: 'Upload a valid JPG, PNG, GIF, or WebP image.',
      });
    }
    return next();
  });
}

router.get('/me', requireAuth, me);
router.patch('/profile', requireAuth, updateProfile);
router.post('/logo', requireAuth, handleLogoUpload, uploadLogo);
router.post('/profile-image', requireAuth, handleLogoUpload, uploadLogo);
router.post(
  '/verify-password',
  requireAuth,
  [
    body('currentPassword')
      .notEmpty()
      .withMessage('Enter your current password'),
  ],
  verifyCurrentPassword,
);
router.post(
  '/change-password',
  requireAuth,
  [
    body('currentPassword')
      .notEmpty()
      .withMessage('Enter your current password'),
    body('newPassword')
      .isLength({ min: 8 })
      .withMessage('Password must be at least 8 characters'),
  ],
  changePassword,
);

module.exports = router;
