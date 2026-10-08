const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { validationResult } = require("express-validator");

const userRepository = require("../repositories/userRepository");
const otpService = require("../services/otpService");
const googleAuthService = require("../services/googleAuthService");
const { uploadToCloudinary } = require("../config/cloudinary");
const logger = require("../config/logger");

function logCaught(req, message, error) {
  const meta = logger.fromRequest(req, error);
  if (error && error.statusCode && error.statusCode < 500) {
    logger.warn(message, meta);
    return;
  }
  logger.error(message, meta);
}

function normalizePhone(value = "") {
  let digits = String(value).replace(/\D/g, "");
  if (digits.startsWith("91") && digits.length === 12) {
    digits = digits.slice(2);
  }
  if (digits.startsWith("0") && digits.length === 11) {
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
    { expiresIn: process.env.JWT_EXPIRES_IN || "7d", algorithm: "HS256" },
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
    const username = String(req.body.username || "").trim();
    const phone = normalizePhone(req.body.phone);
    const password = String(req.body.password || "");

    const existingPhone = await userRepository.findByPhone(phone);
    if (existingPhone) {
      return res.status(409).json({
        success: false,
        message: "An account with this phone number already exists.",
      });
    }

    const existingUsername = await userRepository.findByUsername(username);
    if (existingUsername) {
      return res.status(409).json({
        success: false,
        message: "That username is already taken.",
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
    logCaught(req, "Signup error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to create your account right now.",
    });
  }
}

async function checkUsername(req, res) {
  try {
    const username = String(
      req.query.username || req.body.username || "",
    ).trim();
    if (!username) {
      return res.status(400).json({
        success: false,
        available: false,
        message: "Username is required.",
      });
    }
    if (username.length < 3 || username.length > 24) {
      return res.status(400).json({
        success: false,
        available: false,
        message: "Username must be between 3 and 24 characters.",
      });
    }
    if (!/^[A-Za-z0-9_]+$/.test(username)) {
      return res.status(400).json({
        success: false,
        available: false,
        message: "Username can only contain letters, numbers, and underscores.",
      });
    }

    const existing = await userRepository.findByUsername(username);
    if (existing) {
      return res.json({
        success: true,
        available: false,
        message: "That username is already taken.",
      });
    }

    return res.json({
      success: true,
      available: true,
      message: "Username is available!",
    });
  } catch (error) {
    logCaught(req, "checkUsername error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to check username availability.",
    });
  }
}

async function login(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const rawId =
      req.body.identifier ||
      req.body.username ||
      req.body.email ||
      req.body.phone;
    const identifier = String(rawId || "").trim();
    const password = String(req.body.password || "");

    if (!identifier) {
      return res.status(400).json({
        success: false,
        message: "Enter your email or username.",
      });
    }

    let user = null;

    // 1. If identifier contains '@', try finding by email
    if (identifier.includes("@")) {
      user = await userRepository.findByEmail(identifier);
    }

    // 2. Try finding by username
    if (!user) {
      user = await userRepository.findByUsername(identifier);
    }

    // 3. Fallback for phone number input
    if (!user) {
      const cleaned = normalizePhone(identifier);
      if (cleaned.length === 10) {
        user = await userRepository.findByPhone(cleaned);
      }
    }

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Email, username, or password is incorrect.",
      });
    }

    // Fetch user with password selected
    const userWithPassword = await userRepository.findById(
      user._id || user.id,
      { withPassword: true },
    );
    if (!userWithPassword || !userWithPassword.password) {
      return res.status(401).json({
        success: false,
        message:
          "This account was created with Google Sign-In. Please sign in with Google or set a password.",
      });
    }

    const matches = await bcrypt.compare(password, userWithPassword.password);
    if (!matches) {
      return res.status(401).json({
        success: false,
        message: "Email, username, or password is incorrect.",
      });
    }

    return res.json({
      success: true,
      token: signToken(user),
      user: user.toPublicJSON(),
    });
  } catch (error) {
    logCaught(req, "Login error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to sign in right now.",
    });
  }
}

async function me(req, res) {
  try {
    const user = await userRepository.findById(req.userId);
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Your session is no longer valid.",
      });
    }

    return res.json({
      success: true,
      user: user.toPublicJSON(),
    });
  } catch (error) {
    logCaught(req, "Session error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to restore your session.",
    });
  }
}

const PROFILE_FIELDS = [
  "studioName",
  "ownerName",
  "city",
  "address",
  "about",
  "instagram",
  "youtube",
  "website",
  "specialties",
  "logoUrl",
  "paymentQrUrl",
];

const HOST_PATTERN = /^([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$/;
const HANDLE_PATTERN = /^@?[A-Za-z0-9._-]{1,50}$/;

// Accepts a handle (when `domains` is set) or an http(s) link with a real domain.
function validateLink(value, { label, domains }) {
  const raw = String(value || "").trim();
  if (!raw) return null;
  const invalid = `Enter a valid ${label} link.`;
  const hasScheme = /^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(raw);
  const lower = raw.toLowerCase();
  if (
    domains &&
    !hasScheme &&
    !raw.includes("/") &&
    !domains.some((d) => lower.includes(d))
  ) {
    return HANDLE_PATTERN.test(raw)
      ? null
      : `Enter a valid ${label} handle or link.`;
  }
  if (/\s/.test(raw)) return invalid;
  let url;
  try {
    url = new URL(hasScheme ? raw : `https://${raw}`);
  } catch (_) {
    return invalid;
  }
  if (!["http:", "https:"].includes(url.protocol)) return invalid;
  const host = url.hostname.toLowerCase();
  if (!HOST_PATTERN.test(host)) return invalid;
  if (domains) {
    const bare = host.replace(/^(www|m)\./, "");
    if (!domains.some((d) => bare === d || bare.endsWith(`.${d}`)))
      return invalid;
  }
  return null;
}

function validateProfileFields(fields) {
  const textFields = PROFILE_FIELDS.filter(
    (key) => key !== "logoUrl" && key !== "paymentQrUrl",
  );
  for (const key of textFields) {
    if (fields[key] !== undefined && String(fields[key]).length > 240) {
      return `${key} is too long.`;
    }
  }
  if (fields.email && !/^\S+@\S+\.\S+$/.test(fields.email)) {
    return "Enter a valid email address.";
  }
  const linkRules = {
    website: { label: "website", domains: null },
    instagram: { label: "Instagram", domains: ["instagram.com", "instagr.am"] },
    youtube: { label: "YouTube", domains: ["youtube.com", "youtu.be"] },
  };
  for (const [key, rule] of Object.entries(linkRules)) {
    const error = validateLink(fields[key], rule);
    if (error) return error;
  }
  if (
    fields.logoUrl &&
    (!fields.logoUrl.startsWith("https://") ||
      !fields.logoUrl.includes("cloudinary.com"))
  ) {
    return "Profile images must be hosted securely.";
  }
  if (
    fields.paymentQrUrl &&
    (!fields.paymentQrUrl.startsWith("https://") ||
      !fields.paymentQrUrl.includes("cloudinary.com"))
  ) {
    return "Payment QR images must be hosted securely.";
  }
  return null;
}

async function updateProfile(req, res) {
  try {
    const fields = {};
    for (const key of PROFILE_FIELDS) {
      if (req.body[key] !== undefined) {
        fields[key] = String(req.body[key] || "").trim();
      }
    }

    if (req.body.categories !== undefined) {
      if (Array.isArray(req.body.categories)) {
        fields.categories = req.body.categories
          .map((c) => String(c || "").trim())
          .filter(Boolean)
          .slice(0, 30);
      } else if (typeof req.body.categories === "string") {
        fields.categories = req.body.categories
          .split(",")
          .map((c) => c.trim())
          .filter(Boolean)
          .slice(0, 30);
      }
    }

    if (req.body.latitude !== undefined) {
      const lat = Number(req.body.latitude);
      fields.latitude = !isNaN(lat) ? lat : null;
    }
    if (req.body.longitude !== undefined) {
      const lng = Number(req.body.longitude);
      fields.longitude = !isNaN(lng) ? lng : null;
    }

    // Username change — check availability
    if (req.body.username !== undefined) {
      const newUsername = String(req.body.username || "").trim();
      if (newUsername) {
        if (!/^[A-Za-z0-9_]{3,24}$/.test(newUsername)) {
          return res.status(400).json({
            success: false,
            message:
              "Username must be 3-24 characters (letters, numbers, underscores only)",
          });
        }
        const existingUser = await userRepository.findByUsername(newUsername);
        if (existingUser && existingUser._id.toString() !== req.userId) {
          return res.status(409).json({
            success: false,
            message: "That username is already taken.",
          });
        }
        fields.username = newUsername;
      }
    }

    if (req.body.phone) {
      const phone = normalizePhone(req.body.phone);
      if (phone.length !== 10) {
        return res.status(400).json({
          success: false,
          message: "Enter a valid 10-digit phone number",
        });
      }
      const existing = await userRepository.findByPhone(phone);
      if (existing && existing._id.toString() !== req.userId) {
        return res.status(409).json({
          success: false,
          message: "That phone number is already in use.",
        });
      }
      fields.phone = phone;
    }
    const validationMessage = validateProfileFields(fields);
    if (validationMessage) {
      return res
        .status(400)
        .json({ success: false, message: validationMessage });
    }

    const user = await userRepository.updateUser(req.userId, fields);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Profile not found.",
      });
    }

    return res.json({
      success: true,
      user: user.toPublicJSON(),
    });
  } catch (error) {
    logCaught(req, "Update profile error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to update your profile right now.",
    });
  }
}

/**
 * Send OTP to a new email address for email change verification.
 */
async function sendEmailChangeOtp(req, res) {
  try {
    const newEmail = String(req.body.email || "")
      .trim()
      .toLowerCase();
    if (!newEmail || !/^\S+@\S+\.\S+$/.test(newEmail)) {
      return res
        .status(400)
        .json({ success: false, message: "Enter a valid email address." });
    }
    const existing = await userRepository.findByEmail(newEmail);
    if (existing && existing._id.toString() !== req.userId) {
      return res.status(409).json({
        success: false,
        message: "That email address is already in use.",
      });
    }
    const currentUser = await userRepository.findById(req.userId);
    const result = await otpService.generateAndSendEmailOtp(
      newEmail,
      currentUser?.username || "",
    );
    return res.json({ success: true, ...result });
  } catch (error) {
    logCaught(req, "sendEmailChangeOtp error", error);
    const status = error.statusCode || 500;
    return res.status(status).json({
      success: false,
      message: error.message || "Unable to send verification code.",
    });
  }
}

/**
 * Verify OTP and update the user's email address.
 */
async function verifyEmailChange(req, res) {
  try {
    const newEmail = String(req.body.email || "")
      .trim()
      .toLowerCase();
    const otp = String(req.body.otp || "").trim();
    if (!newEmail || !/^\S+@\S+\.\S+$/.test(newEmail)) {
      return res
        .status(400)
        .json({ success: false, message: "Enter a valid email address." });
    }
    if (!otp || otp.length !== 6) {
      return res.status(400).json({
        success: false,
        message: "Enter the 6-digit verification code.",
      });
    }
    const existing = await userRepository.findByEmail(newEmail);
    if (existing && existing._id.toString() !== req.userId) {
      return res.status(409).json({
        success: false,
        message: "That email address is already in use.",
      });
    }
    await otpService.verifyEmailOtp(newEmail, otp);
    const user = await userRepository.updateUser(req.userId, {
      email: newEmail,
    });
    if (!user) {
      return res
        .status(404)
        .json({ success: false, message: "Profile not found." });
    }
    return res.json({ success: true, user: user.toPublicJSON() });
  } catch (error) {
    logCaught(req, "verifyEmailChange error", error);
    const status = error.statusCode || 400;
    return res.status(status).json({
      success: false,
      message: error.message || "Unable to verify email.",
    });
  }
}

async function uploadLogo(req, res) {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "Choose a profile image or studio logo to upload.",
      });
    }

    // 1. Upload file strictly to Cloudinary CDN
    const cloudinaryResult = await uploadToCloudinary(req.file.path, {
      folder: "lumen_studio/profiles",
    });

    let logoUrl = cloudinaryResult.secure_url || cloudinaryResult.url || "";
    if (logoUrl.startsWith("http://")) {
      logoUrl = `https://${logoUrl.substring(7)}`;
    }

    if (!logoUrl.startsWith("https://")) {
      return res.status(500).json({
        success: false,
        message: "Cloudinary did not return a valid HTTPS image URL.",
      });
    }

    // 2. Save ONLY the Cloudinary HTTPS URL in MongoDB (no base64 / binary stored in database)
    const user = await userRepository.updateUser(req.userId, { logoUrl });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Profile not found.",
      });
    }

    return res.json({
      success: true,
      imageUrl: logoUrl,
      user: user.toPublicJSON(),
    });
  } catch (error) {
    logCaught(req, "Logo upload error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to upload your profile image right now.",
    });
  }
}

async function uploadPaymentQr(req, res) {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: "Choose your payment QR image to upload.",
      });
    }

    const cloudinaryResult = await uploadToCloudinary(req.file.path, {
      folder: `lumen_studio/payment_qr/${req.userId}`,
    });

    let paymentQrUrl =
      cloudinaryResult.secure_url || cloudinaryResult.url || "";
    if (paymentQrUrl.startsWith("http://")) {
      paymentQrUrl = `https://${paymentQrUrl.substring(7)}`;
    }
    if (!paymentQrUrl.startsWith("https://")) {
      return res.status(500).json({
        success: false,
        message: "Cloudinary did not return a valid HTTPS image URL.",
      });
    }

    const user = await userRepository.updateUser(req.userId, { paymentQrUrl });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Profile not found.",
      });
    }

    return res.json({
      success: true,
      imageUrl: paymentQrUrl,
      user: user.toPublicJSON(),
    });
  } catch (error) {
    logCaught(req, "Payment QR upload error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to upload your payment QR right now.",
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
        message: "No registered studio account found with this phone number.",
      });
    }

    const result = await otpService.generateAndSendOtp(phone);
    return res.json(result);
  } catch (error) {
    logCaught(req, "forgotPasswordSendOtp error", error);
    const status = error.statusCode || 500;
    return res.status(status).json({
      success: false,
      message: error.message || "Unable to send OTP at this time.",
    });
  }
}

async function forgotPasswordVerifyOtp(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const phone = normalizePhone(req.body.phone);
    const otp = String(req.body.otp || "").trim();

    const result = await otpService.verifyOtpAndIssueResetToken(phone, otp);
    return res.json(result);
  } catch (error) {
    logCaught(req, "forgotPasswordVerifyOtp error", error);
    const status = error.statusCode || 400;
    return res.status(status).json({
      success: false,
      message: error.message || "Unable to verify OTP.",
    });
  }
}

async function forgotPasswordVerifyUsername(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const username = String(req.body.username || "").trim();
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
        action: "reset_password",
      },
      process.env.JWT_SECRET,
      { expiresIn: "15m" },
    );

    const phone = user.phone || "";
    const maskedPhone =
      phone.length >= 4
        ? "•".repeat(Math.max(0, phone.length - 4)) + phone.slice(-4)
        : phone;

    return res.json({
      success: true,
      message: "Account verified successfully.",
      username: user.username,
      maskedPhone,
      resetToken,
    });
  } catch (error) {
    logCaught(req, "forgotPasswordVerifyUsername error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to verify username right now.",
    });
  }
}

async function forgotPasswordReset(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const username = String(req.body.username || "").trim();
    const resetToken = String(req.body.resetToken || "").trim();
    const newPassword = String(req.body.newPassword || "");

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
        message: "Account not found. Please verify your username again.",
      });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 12);
    await userRepository.updateUser(user._id || user.id, {
      password: hashedPassword,
    });

    return res.json({
      success: true,
      message:
        "Password reset successfully. You can now sign in with your new password.",
    });
  } catch (error) {
    logCaught(req, "forgotPasswordReset error", error);
    const status = error.statusCode || 500;
    return res.status(status).json({
      success: false,
      message: error.message || "Unable to reset password.",
    });
  }
}

async function signupSendOtp(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const username = String(req.body.username || "").trim();
    const phone = normalizePhone(req.body.phone);

    const existingPhone = await userRepository.findByPhone(phone);
    if (existingPhone) {
      return res.status(409).json({
        success: false,
        message: "An account with this phone number already exists.",
      });
    }

    const existingUsername = await userRepository.findByUsername(username);
    if (existingUsername) {
      return res.status(409).json({
        success: false,
        message: "That username is already taken.",
      });
    }

    const result = await otpService.generateAndSendOtp(phone);
    return res.json(result);
  } catch (error) {
    logCaught(req, "signupSendOtp error", error);
    const status = error.statusCode || 500;
    return res.status(status).json({
      success: false,
      message: error.message || "Unable to send signup verification code.",
    });
  }
}

async function signupVerify(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const username = String(req.body.username || "").trim();
    const phone = normalizePhone(req.body.phone);
    const password = String(req.body.password || "");
    const otp = String(req.body.otp || "").trim();

    const existingPhone = await userRepository.findByPhone(phone);
    if (existingPhone) {
      return res.status(409).json({
        success: false,
        message: "An account with this phone number already exists.",
      });
    }

    const existingUsername = await userRepository.findByUsername(username);
    if (existingUsername) {
      return res.status(409).json({
        success: false,
        message: "That username is already taken.",
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
    logCaught(req, "signupVerify error", error);
    const status = error.statusCode || 400;
    return res.status(status).json({
      success: false,
      message: error.message || "Unable to verify code and complete signup.",
    });
  }
}

async function signupSendEmailOtp(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const username = String(req.body.username || "").trim();
    const email = String(req.body.email || "")
      .trim()
      .toLowerCase();

    const existingUsername = await userRepository.findByUsername(username);
    if (existingUsername) {
      return res.status(409).json({
        success: false,
        message: "That username is already taken. Please choose another.",
      });
    }

    const existingEmail = await userRepository.findByEmail(email);
    if (existingEmail) {
      return res.status(409).json({
        success: false,
        message: "An account with this email address already exists.",
      });
    }

    const result = await otpService.generateAndSendEmailOtp(email, username);
    return res.json(result);
  } catch (error) {
    logCaught(req, "signupSendEmailOtp error", error);
    const status = error.statusCode || 500;
    return res.status(status).json({
      success: false,
      message: error.message || "Unable to send signup verification code.",
    });
  }
}

async function signupVerifyEmail(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const username = String(req.body.username || "").trim();
    const email = String(req.body.email || "")
      .trim()
      .toLowerCase();
    const password = String(req.body.password || "");
    const otp = String(req.body.otp || "").trim();
    const phone = req.body.phone ? normalizePhone(req.body.phone) : "";

    const existingUsername = await userRepository.findByUsername(username);
    if (existingUsername) {
      return res.status(409).json({
        success: false,
        message: "That username is already taken.",
      });
    }

    const existingEmail = await userRepository.findByEmail(email);
    if (existingEmail) {
      return res.status(409).json({
        success: false,
        message: "An account with this email address already exists.",
      });
    }

    if (phone) {
      const existingPhone = await userRepository.findByPhone(phone);
      if (existingPhone) {
        return res.status(409).json({
          success: false,
          message: "An account with this phone number already exists.",
        });
      }
    }

    await otpService.verifyEmailOtp(email, otp);

    const hashedPassword = await bcrypt.hash(password, 12);
    const user = await userRepository.createUser({
      username,
      email,
      phone, // Plain text! No AES encryption applied to phone
      password: hashedPassword,
    });

    const publicJson = user.toPublicJSON();
    publicJson.needsPasswordSetup = false;

    return res.status(201).json({
      success: true,
      token: signToken(user),
      user: publicJson,
      needsPasswordSetup: false,
    });
  } catch (error) {
    logCaught(req, "signupVerifyEmail error", error);
    const status = error.statusCode || 400;
    return res.status(status).json({
      success: false,
      message: error.message || "Unable to verify code and complete signup.",
    });
  }
}

async function verifyCurrentPassword(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const currentPassword = String(req.body.currentPassword || "");
    const user = await userRepository.findById(req.userId, {
      withPassword: true,
    });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Account not found.",
      });
    }

    const matches = await bcrypt.compare(currentPassword, user.password);
    if (!matches) {
      return res.status(400).json({
        success: false,
        message: "Current password is incorrect.",
      });
    }

    return res.json({
      success: true,
      message: "Current password verified.",
    });
  } catch (error) {
    logCaught(req, "verifyCurrentPassword error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to verify password right now.",
    });
  }
}

async function changePassword(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const currentPassword = String(req.body.currentPassword || "");
    const newPassword = String(req.body.newPassword || "");

    const user = await userRepository.findById(req.userId, {
      withPassword: true,
    });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Account not found.",
      });
    }

    const matches = await bcrypt.compare(currentPassword, user.password);
    if (!matches) {
      return res.status(400).json({
        success: false,
        message: "Current password is incorrect.",
      });
    }

    if (currentPassword === newPassword) {
      return res.status(400).json({
        success: false,
        message: "New password cannot be the same as your current password.",
      });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 12);
    await userRepository.updateUser(user._id || user.id, {
      password: hashedPassword,
    });

    return res.json({
      success: true,
      message: "Password changed successfully.",
    });
  } catch (error) {
    logCaught(req, "changePassword error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to update password right now.",
    });
  }
}

async function googleAuth(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const idToken = req.body.idToken || req.body.token || req.body.credential;
    const accessToken = req.body.accessToken;

    if (!idToken && !accessToken) {
      return res.status(400).json({
        success: false,
        message: "Google authorization token is required.",
      });
    }

    let profile;
    try {
      profile = await googleAuthService.verifyGoogleToken({
        idToken,
        accessToken,
      });
    } catch (verifyErr) {
      logger.warn("Google token verification failed", {
        error: verifyErr.message,
      });
      return res.status(401).json({
        success: false,
        message: "Invalid or expired Google authorization token.",
      });
    }

    if (!profile || !profile.googleId) {
      return res.status(401).json({
        success: false,
        message: "Could not retrieve Google profile information.",
      });
    }

    // 1. Check if user already exists by googleId
    let user = await userRepository.findByGoogleId(profile.googleId);

    // 2. If not found by googleId, check if email matches an existing account
    if (!user && profile.email) {
      user = await userRepository.findByEmail(profile.email);
      if (user) {
        // Link googleId to this user account
        user = await userRepository.updateUser(user._id || user.id, {
          googleId: profile.googleId,
          ...(profile.picture && !user.logoUrl
            ? { logoUrl: profile.picture }
            : {}),
          ...(profile.name && !user.ownerName
            ? { ownerName: profile.name }
            : {}),
        });
      }
    }

    // 3. If still no user, create a new user profile
    if (!user) {
      let baseUsername = (profile.name || profile.email.split("@")[0] || "user")
        .toLowerCase()
        .replace(/[^a-z0-9_]/g, "_")
        .slice(0, 16);
      if (baseUsername.length < 3) baseUsername = `user_${baseUsername}`;

      let candidateUsername = baseUsername;
      let existing = await userRepository.findByUsername(candidateUsername);
      let suffix = 1;
      while (existing && suffix < 100) {
        candidateUsername = `${baseUsername.slice(0, 14)}_${Math.floor(1000 + Math.random() * 9000)}`;
        existing = await userRepository.findByUsername(candidateUsername);
        suffix++;
      }

      user = await userRepository.createUser({
        username: candidateUsername,
        googleId: profile.googleId,
        email: profile.email || "",
        ownerName: profile.name || candidateUsername,
        logoUrl: profile.picture || "",
        phone: "",
      });
    }

    const userWithPassword = await userRepository.findById(
      user._id || user.id,
      { withPassword: true },
    );
    const needsPasswordSetup = !userWithPassword || !userWithPassword.password;

    const publicJson = user.toPublicJSON();
    publicJson.needsPasswordSetup = needsPasswordSetup;

    return res.json({
      success: true,
      token: signToken(user),
      user: publicJson,
      needsPasswordSetup,
    });
  } catch (error) {
    logCaught(req, "Google auth error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to authenticate with Google right now.",
    });
  }
}

async function setPassword(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const newPassword = String(req.body.newPassword || "");
    if (!newPassword || newPassword.length < 8) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 8 characters.",
      });
    }

    const hashedPassword = await bcrypt.hash(newPassword, 12);
    const updated = await userRepository.updateUser(req.userId, {
      password: hashedPassword,
    });
    if (!updated) {
      return res.status(404).json({
        success: false,
        message: "Account not found.",
      });
    }

    const publicJson = updated.toPublicJSON();
    publicJson.needsPasswordSetup = false;

    return res.json({
      success: true,
      message: "Password set successfully.",
      user: publicJson,
      needsPasswordSetup: false,
    });
  } catch (error) {
    logCaught(req, "setPassword error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to set password right now.",
    });
  }
}

async function deleteAccountSendOtp(req, res) {
  try {
    const user = await userRepository.findById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Account not found.",
      });
    }

    const email = user.email ? String(user.email).trim().toLowerCase() : "";
    if (!email) {
      return res.status(400).json({
        success: false,
        message: "No registered email found for this account.",
      });
    }

    const result = await otpService.generateAndSendEmailOtp(email);
    return res.json({
      success: true,
      message: result.message,
      email,
    });
  } catch (error) {
    logCaught(req, "deleteAccountSendOtp error", error);
    const status = error.statusCode || 500;
    return res.status(status).json({
      success: false,
      message:
        error.message || "Unable to send verification code at this time.",
    });
  }
}

async function deleteAccount(req, res) {
  try {
    const user = await userRepository.findById(req.userId, {
      withPassword: true,
    });
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Account not found.",
      });
    }

    const otp = String(req.body.otp || req.query.otp || "").trim();
    const password = String(req.body.password || req.query.password || "");

    if (!otp) {
      return res.status(400).json({
        success: false,
        message: "Please provide the email verification code.",
      });
    }

    if (!password) {
      return res.status(400).json({
        success: false,
        message: "Please provide your account password to confirm deletion.",
      });
    }

    // 1. Verify email OTP (verify user owns email)
    try {
      await otpService.verifyEmailOtp(user.email, otp);
    } catch (otpErr) {
      return res.status(400).json({
        success: false,
        message: otpErr.message || "Invalid or expired verification code.",
      });
    }

    // 2. Verify account password
    if (user.password) {
      const isMatch = await bcrypt.compare(password, user.password);
      if (!isMatch) {
        return res.status(400).json({
          success: false,
          message: "Incorrect password. Account deletion aborted.",
        });
      }
    }

    await userRepository.deleteUserAccount(req.userId);
    return res.json({
      success: true,
      message: "Account and associated data deleted successfully.",
    });
  } catch (error) {
    logCaught(req, "Delete account error", error);
    return res.status(500).json({
      success: false,
      message: "Unable to delete account at this time.",
    });
  }
}

async function sendEmailChangeOtp(req, res) {
  try {
    const user = await userRepository.findById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Account not found.",
      });
    }

    const newEmail = String(req.body.newEmail || "")
      .trim()
      .toLowerCase();
    if (!newEmail || !/^\S+@\S+\.\S+$/.test(newEmail)) {
      return res.status(400).json({
        success: false,
        message: "Enter a valid email address.",
      });
    }

    if (user.email && user.email.toLowerCase() === newEmail) {
      return res.status(400).json({
        success: false,
        message: "New email cannot be the same as your current email.",
      });
    }

    // Check if new email is already taken by another user
    const existing = await userRepository.findByEmail(newEmail);
    if (existing && existing._id.toString() !== req.userId) {
      return res.status(409).json({
        success: false,
        message: "That email is already registered with another account.",
      });
    }

    const result = await otpService.generateAndSendEmailOtp(newEmail);
    return res.json({
      success: true,
      message: result.message,
      email: newEmail,
    });
  } catch (error) {
    logCaught(req, "sendEmailChangeOtp error", error);
    const status = error.statusCode || 500;
    return res.status(status).json({
      success: false,
      message:
        error.message || "Unable to send verification code at this time.",
    });
  }
}

async function verifyEmailChange(req, res) {
  try {
    const user = await userRepository.findById(req.userId);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "Account not found.",
      });
    }

    const newEmail = String(req.body.newEmail || "")
      .trim()
      .toLowerCase();
    const otp = String(req.body.otp || "").trim();

    if (!newEmail || !/^\S+@\S+\.\S+$/.test(newEmail)) {
      return res.status(400).json({
        success: false,
        message: "Enter a valid email address.",
      });
    }

    if (!otp) {
      return res.status(400).json({
        success: false,
        message: "Please provide the verification code.",
      });
    }

    // Double check email uniqueness
    const existing = await userRepository.findByEmail(newEmail);
    if (existing && existing._id.toString() !== req.userId) {
      return res.status(409).json({
        success: false,
        message: "That email is already registered with another account.",
      });
    }

    try {
      await otpService.verifyEmailOtp(newEmail, otp);
    } catch (otpErr) {
      return res.status(400).json({
        success: false,
        message: otpErr.message || "Invalid or expired verification code.",
      });
    }

    const updatedUser = await userRepository.updateUser(req.userId, {
      email: newEmail,
    });
    return res.json({
      success: true,
      message: "Email updated successfully.",
      user: updatedUser.toPublicJSON ? updatedUser.toPublicJSON() : updatedUser,
    });
  } catch (error) {
    logCaught(req, "verifyEmailChange error", error);
    const status = error.statusCode || 500;
    return res.status(status).json({
      success: false,
      message: error.message || "Unable to update email at this time.",
    });
  }
}

module.exports = {
  checkUsername,
  signup,
  signupSendOtp,
  signupVerify,
  signupSendEmailOtp,
  signupVerifyEmail,
  login,
  googleAuth,
  setPassword,
  me,
  updateProfile,
  uploadLogo,
  uploadPaymentQr,
  normalizePhone,
  forgotPasswordSendOtp,
  forgotPasswordVerifyOtp,
  forgotPasswordReset,
  forgotPasswordVerifyUsername,
  verifyCurrentPassword,
  changePassword,
  deleteAccountSendOtp,
  deleteAccount,
  sendEmailChangeOtp,
  verifyEmailChange,
};
