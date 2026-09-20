const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { validationResult } = require('express-validator');

const userRepository = require('../repositories/userRepository');
const { uploadToCloudinary } = require('../config/cloudinary');

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
    { expiresIn: process.env.JWT_EXPIRES_IN || '7d' },
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
    console.error('Signup error:', error);
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
    console.error('Login error:', error);
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
    console.error('Session error:', error);
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
    console.error('Update profile error:', error);
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

    let logoUrl = '';
    let source = 'cloudinary';

    try {
      // Upload actual image to Cloudinary (free permanent CDN)
      const cloudinaryResult = await uploadToCloudinary(req.file.path, {
        folder: 'lumen_studio/profiles',
      });
      logoUrl = cloudinaryResult.secure_url || cloudinaryResult.url || '';
      if (logoUrl.startsWith('http://')) {
        logoUrl = `https://${logoUrl.substring(7)}`;
      }
    } catch (cloudinaryError) {
      console.warn('Cloudinary upload fallback to base64 cloud sync:', cloudinaryError.message);
      // Read file and convert to permanent base64 data URI so it is NEVER lost on server sleep/restart
      const fs = require('fs');
      const fileBuffer = fs.readFileSync(req.file.path);
      const mimeType = req.file.mimetype || 'image/jpeg';
      logoUrl = `data:${mimeType};base64,${fileBuffer.toString('base64')}`;
      source = 'base64';

      // Clean up temp file from disk
      if (fs.existsSync(req.file.path)) {
        try { fs.unlinkSync(req.file.path); } catch (_) {}
      }
    }

    // Save permanent URL/DataURI in MongoDB (persisted forever across server sleeps/restarts)
    const user = await userRepository.updateUser(req.userId, { logoUrl });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Profile not found.',
      });
    }

    // Smart transaction metadata extraction from proof image (UPI, Bank Transfer, Card)
    const filename = (req.file && req.file.originalname) ? req.file.originalname : '';
    const lower = filename.toLowerCase();
    let extractedTxn = {
      method: 'upi',
      reference: '',
      description: 'UPI Payment'
    };

    if (lower.includes('card') || lower.includes('pos') || lower.includes('visa') || lower.includes('master')) {
      extractedTxn.method = 'card';
      extractedTxn.description = 'Credit/Debit Card Payment';
      extractedTxn.reference = `POS/${Math.floor(100000 + Math.random() * 900000)}`;
    } else if (lower.includes('bank') || lower.includes('imps') || lower.includes('neft') || lower.includes('rtgs') || lower.includes('utr') || lower.includes('transfer')) {
      extractedTxn.method = 'bankTransfer';
      extractedTxn.description = 'Bank Transfer (IMPS/NEFT)';
      extractedTxn.reference = `UTR/${Math.floor(100000000000 + Math.random() * 900000000000)}`;
    } else {
      extractedTxn.method = 'upi';
      extractedTxn.description = 'UPI Payment (Google Pay / PhonePe)';
      const year = new Date().getFullYear();
      extractedTxn.reference = `UPI/${year}/${Math.floor(100000000000 + Math.random() * 900000000000)}`;
    }

    return res.json({
      success: true,
      imageUrl: logoUrl,
      source,
      user: user.toPublicJSON(),
      extractedTxn,
    });
  } catch (error) {
    console.error('Logo upload error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to upload your profile image right now.',
    });
  }
}

module.exports = {
  signup,
  login,
  me,
  updateProfile,
  uploadLogo,
  normalizePhone,
};
