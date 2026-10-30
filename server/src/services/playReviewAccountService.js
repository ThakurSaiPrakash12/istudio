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

  if (existing) {
    await repository.updateUser(existing._id || existing.id, {
      password: hashedPassword,
      isReviewAccount: true,
    });
    return { created: false };
  }

  const usernameSuffix = crypto.createHash('sha256').update(normalizedEmail).digest('hex').slice(0, 12);
  await repository.createUser({
    username: `${prefix}_${usernameSuffix}`,
    email: normalizedEmail,
    ownerName: label,
    password: hashedPassword,
    isReviewAccount: true,
  });
  return { created: true };
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

module.exports = { ensureReviewAccount, ensurePlayReviewAccount, ensureAppleReviewAccount };