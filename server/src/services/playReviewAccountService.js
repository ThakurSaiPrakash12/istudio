const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const userRepository = require('../repositories/userRepository');

/**
 * Create or update a store-review demo account.
 *
 * The account is fully functional for login but marked with
 * `isReviewAccount: true` so it is excluded from public
 * Photographer Discovery results.
 *
 * @param {Object}  opts
 * @param {string}  opts.email    - Review account email
 * @param {string}  opts.password - Review account password
 * @param {string}  opts.prefix   - Username prefix (e.g. 'play_review', 'apple_review')
 * @param {string}  opts.label    - Human-readable label (e.g. 'Google Play Reviewer')
 * @param {Object}  [opts.repository] - User repository (for testing)
 */
async function ensureReviewAccount({
  email,
  password,
  prefix = 'review',
  label = 'App Store Reviewer',
  repository = userRepository,
}) {
  const normalizedEmail = String(email || '').trim().toLowerCase();
  const reviewPassword = String(password || '');

  if (!normalizedEmail && !reviewPassword) return null;
  if (!normalizedEmail || !reviewPassword) {
    throw new Error(`${label} credentials incomplete — both email and password are required.`);
  }
  if (!normalizedEmail.includes('@') || reviewPassword.length < 8) {
    throw new Error(`${label} credentials are invalid.`);
  }

  const existing = await repository.findByEmail(normalizedEmail);
  const hashedPassword = await bcrypt.hash(reviewPassword, 12);

  const fullProfile = {
    studioName: 'Clients Hub Studio',
    phone: '9999900001',
    city: 'Cupertino',
    state: 'California',
    district: 'Santa Clara',
    address: '1 Infinite Loop, Cupertino, CA 95014',
    specialties: 'Traditional & Candid Photography',
    about: 'Official Clients Hub demonstration studio for App Store evaluation.',
    categories: ['Traditional Photographer', 'Candid Photographer', 'Cinematographer'],
    latitude: 37.33182,
    longitude: -122.03118,
    isReviewAccount: true,
  };

  if (existing) {
    await repository.updateUser(existing._id || existing.id, {
      password: hashedPassword,
      ...fullProfile,
    });
    return { created: false };
  }

  const usernameSuffix = crypto.createHash('sha256').update(normalizedEmail).digest('hex').slice(0, 12);
  await repository.createUser({
    username: `${prefix}_${usernameSuffix}`,
    email: normalizedEmail,
    ownerName: label,
    password: hashedPassword,
    ...fullProfile,
  });
  return { created: true };
}

// Review accounts use dummy mailboxes, so no real verification email can be
// received. Account deletion accepts this fixed code for them instead.
const REVIEW_DELETE_OTP = process.env.REVIEW_DELETE_OTP || '123456';

function getReviewAccountConfigs() {
  const configs = [
    {
      email: process.env.APPLE_REVIEW_EMAIL || 'applereview@clientshub.com',
      password: process.env.APPLE_REVIEW_PASSWORD || '123456789',
      prefix: 'apple_review',
      label: 'Apple App Store Reviewer',
    },
    {
      email: process.env.PLAY_REVIEW_EMAIL,
      password: process.env.PLAY_REVIEW_PASSWORD,
      prefix: 'play_review',
      label: 'Google Play Reviewer',
    },
  ];
  return configs
    .map((c) => ({ ...c, email: String(c.email || '').trim().toLowerCase() }))
    .filter((c) => c.email && c.password);
}

function isReviewEmail(email) {
  const normalized = String(email || '').trim().toLowerCase();
  return !!normalized && getReviewAccountConfigs().some((c) => c.email === normalized);
}

function isReviewDeleteOtp(email, otp) {
  return isReviewEmail(email) && String(otp || '').trim() === REVIEW_DELETE_OTP;
}

/**
 * Re-create a deleted review account as a brand-new, empty user when someone
 * logs in with its credentials. Returns the created user, or null when the
 * identifier/password do not match a review account.
 */
async function createFreshReviewAccountIfCredentialsMatch(
  identifier,
  password,
  repository = userRepository,
) {
  const normalized = String(identifier || '').trim().toLowerCase();
  const config = getReviewAccountConfigs().find((c) => c.email === normalized);
  if (!config || String(password || '') !== String(config.password)) return null;

  const usernameSuffix = crypto.createHash('sha256').update(config.email).digest('hex').slice(0, 12);
  return repository.createUser({
    username: `${config.prefix}_${usernameSuffix}`,
    email: config.email,
    password: await bcrypt.hash(String(config.password), 12),
    isReviewAccount: true,
  });
}

/**
 * Ensures the Google Play review account exists (backward-compatible).
 */
async function ensurePlayReviewAccount({
  email = process.env.PLAY_REVIEW_EMAIL,
  password = process.env.PLAY_REVIEW_PASSWORD,
  repository = userRepository,
} = {}) {
  return ensureReviewAccount({
    email,
    password,
    prefix: 'play_review',
    label: 'Google Play Reviewer',
    repository,
  });
}

/**
 * Ensures the Apple App Store review account exists.
 */
async function ensureAppleReviewAccount({
  email = process.env.APPLE_REVIEW_EMAIL || 'applereview@clientshub.com',
  password = process.env.APPLE_REVIEW_PASSWORD || 'ClientsHub@Review2024',
  repository = userRepository,
} = {}) {
  return ensureReviewAccount({
    email,
    password,
    prefix: 'apple_review',
    label: 'Apple App Store Reviewer',
    repository,
  });
}

module.exports = {
  ensureReviewAccount,
  ensurePlayReviewAccount,
  ensureAppleReviewAccount,
  isReviewEmail,
  isReviewDeleteOtp,
  createFreshReviewAccountIfCredentialsMatch,
};