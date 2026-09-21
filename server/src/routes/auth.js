const express = require('express');
const { body } = require('express-validator');

const {
  login,
  me,
  signup,
  updateProfile,
  uploadLogo,
  normalizePhone,
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

router.post(
  '/signup',
  [
    body('username')
      .trim()
      .isLength({ min: 3, max: 24 })
      .withMessage('Username must be 3-24 characters')
      .matches(/^[A-Za-z0-9_]+$/)
      .withMessage('Username can only include letters, numbers, and underscores'),
    phoneRule,
    body('password')
      .isLength({ min: 8 })
      .withMessage('Password must be at least 8 characters'),
  ],
  signup,
);

router.post(
  '/login',
  [
    phoneRule,
    body('password').notEmpty().withMessage('Enter your password'),
  ],
  login,
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

module.exports = router;
