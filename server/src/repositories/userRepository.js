const User = require('../models/User');
const memoryUsers = require('../store/memoryUsers');
const dataSecurity = require('../services/dataSecurity');
const fuzzySearch = require('../utils/fuzzySearch');

async function findByPhone(phone, { withPassword = false } = {}) {
  if (memoryUsers.enabled) {
    return memoryUsers.findByPhone(phone, withPassword);
  }

  // Phone is stored as plain text. We also fall back to the legacy
  // deterministic-encrypted form so that any old records still match.
  const rawPhone = String(phone).trim();
  const encryptedPhone = dataSecurity.encryptDeterministic(rawPhone);
  const query = User.findOne({
    $or: [{ phone: rawPhone }, { phone: encryptedPhone }],
  });
  if (withPassword) query.select('+password');
  return query;
}

async function findByUsername(username) {
  if (memoryUsers.enabled) {
    return memoryUsers.findByUsername(username);
  }

  return User.findOne({
    username: { $regex: new RegExp(`^${escapeRegex(username)}$`, 'i') },
  });
}

async function findById(id, { withPassword = false } = {}) {
  if (memoryUsers.enabled) {
    return memoryUsers.findById(id, withPassword);
  }
  const query = User.findById(id);
  if (withPassword) query.select('+password');
  return query;
}

async function findByGoogleId(googleId) {
  if (!googleId) return null;
  if (memoryUsers.enabled) {
    return memoryUsers.findByGoogleId(googleId);
  }
  return User.findOne({ googleId });
}

async function findByEmail(email) {
  if (!email) return null;
  if (memoryUsers.enabled) {
    return memoryUsers.findByEmail(email);
  }
  const rawEmail = String(email).trim().toLowerCase();
  // Email is stored as plain text (case-insensitive lookup)
  return User.findOne({
    email: { $regex: new RegExp(`^${escapeRegex(rawEmail)}$`, 'i') },
  });
}

async function createUser(data) {
  const { username, phone = '', password = '', googleId = null, email = '', ownerName = '', logoUrl = '', address = '', isReviewAccount = false } = data;
  const cleanPhone = String(phone || '').trim();
  const cleanEmail = String(email || '').trim().toLowerCase();

  if (memoryUsers.enabled) {
    return memoryUsers.create({ username, phone: cleanPhone, password, googleId, email: cleanEmail, ownerName: ownerName || username, logoUrl, address, categories: data.categories || [], isReviewAccount });
  }
  return User.create({
    username,
    phone: cleanPhone || '',
    password: password || undefined,
    googleId: googleId || undefined,
    email: cleanEmail || '',
    ownerName: ownerName || username,
    logoUrl: logoUrl || '',
    address: address ? dataSecurity.encrypt(address) : '',
    categories: Array.isArray(data.categories) ? data.categories : [],
    isReviewAccount: isReviewAccount || false,
  });
}

async function updateUser(id, fields) {
  const secureFields = { ...fields };
  if (secureFields.phone !== undefined) {
    secureFields.phone = String(secureFields.phone || '').trim();
  }
  if (secureFields.email !== undefined) {
    secureFields.email = String(secureFields.email || '').trim().toLowerCase();
  }
  if (secureFields.address) {
    secureFields.address = dataSecurity.encrypt(secureFields.address);
  }
  if (secureFields.categories !== undefined) {
    secureFields.categories = Array.isArray(secureFields.categories)
      ? secureFields.categories
      : [];
  }

  if (memoryUsers.enabled) {
    return memoryUsers.update(id, fields);
  }
  return User.findByIdAndUpdate(id, { $set: secureFields }, { new: true });
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function deleteUserAccount(userId) {
  if (memoryUsers.enabled) {
    memoryUsers.remove(userId);
    const memoryInvoices = require('../store/memoryInvoices');
    const userInvoices = memoryInvoices.listByUser(userId);
    for (const inv of userInvoices) {
      memoryInvoices.remove(inv.id, userId);
    }
    return true;
  }

  const Client = require('../models/Client');
  const Event = require('../models/Event');
  const Payment = require('../models/Payment');
  const Expense = require('../models/Expense');
  const Deliverable = require('../models/Deliverable');
  const { Invoice } = require('../models/Invoice');

  await Promise.all([
    Client.deleteMany({ userId }),
    Event.deleteMany({ userId }),
    Payment.deleteMany({ userId }),
    Expense.deleteMany({ userId }),
    Deliverable.deleteMany({ userId }),
    Invoice.deleteMany({ userId }),
    User.deleteOne({ _id: userId }),
  ]);
  return true;
}

/**
 * Search for photographer profiles matching a free-text query.
 *
 * Strategy:
 *   1. Build a MongoDB candidate query on NON-encrypted plain-text fields
 *      (city, district, state, studioName, ownerName, username, specialties,
 *       about, categories).  The `address` field is AES-256-GCM encrypted with
 *       a random IV — plaintext regex against ciphertext never matches and is
 *       intentionally excluded here.
 *   2. Include per-token typo-tolerant patterns for tokens ≥ 3 chars.
 *   3. Include category synonym expansion (e.g. "wedding" → Traditional Photographer).
 *   4. Fallback: if the primary query returns 0 candidates, broaden to all
 *      users matching any active pre-filters so extreme typos are still caught.
 *   5. Always run JS fuzzy scoring on every candidate; sort by score descending.
 *      The JS scorer decrypts `address` in-memory (Mongoose post-init) and
 *      includes it in scoring so address-only profiles are still ranked.
 */
async function searchPhotographers({ userId, location, query, state, district, category, categories, limit = 50, includeSelf = false }) {
  if (memoryUsers.enabled) {
    return memoryUsers.searchPhotographers({ userId, location, query, state, district, category, categories, limit, includeSelf });
  }

  const mongoose = require('mongoose');
  const baseFilter = { isReviewAccount: { $ne: true } };
  if (!includeSelf && userId && mongoose.Types.ObjectId.isValid(userId)) {
    baseFilter._id = { $ne: userId };
  }

  // ── Structured pre-filters (state / district / explicit categories) ────────
  const baseConditions = [];
  const normalizedState    = String(state    || '').trim();
  const normalizedDistrict = String(district || '').trim();

  if (normalizedState) {
    baseConditions.push({ state: { $regex: escapeRegex(normalizedState), $options: 'i' } });
  }
  if (normalizedDistrict) {
    baseConditions.push({
      $or: [
        { district: { $regex: escapeRegex(normalizedDistrict), $options: 'i' } },
        { district: { $in: ['', null] }, city: { $regex: escapeRegex(normalizedDistrict), $options: 'i' } },
      ],
    });
  }

  const catList = Array.isArray(categories) && categories.length > 0
    ? categories.map((c) => String(c).trim()).filter(Boolean)
    : (category && String(category).trim() ? [String(category).trim()] : []);

  if (catList.length > 0) {
    const catConditions = catList.map((catItem) => {
      const escapedCat = escapeRegex(catItem);
      return {
        $or: [
          { categories: { $elemMatch: { $regex: escapedCat, $options: 'i' } } },
          { specialties: { $regex: escapedCat, $options: 'i' } },
        ],
      };
    });
    baseConditions.push({ $or: catConditions });
  }

  const loc = String(location || query || '').trim();

  // ── No free-text query — apply base filters only ──────────────────────────
  if (!loc) {
    const filter = { ...baseFilter };
    if (baseConditions.length > 0) filter.$and = baseConditions;
    return User.find(filter).limit(Number(limit) || 50);
  }

  // ── Candidate retrieval — plain-text fields only ──────────────────────────
  const normLoc     = fuzzySearch.normalizeText(loc);
  const escapedLoc  = escapeRegex(loc);
  const squashedLoc = escapeRegex(fuzzySearch.squashText(loc));

  // Only tokens ≥ 3 chars generate per-token regex clauses
  const meaningfulTokens  = normLoc.split(' ').filter((t) => t.length >= 3);
  const relatedCategories = fuzzySearch.getRelatedCategoriesForQuery(loc);

  // All plain-text fields to run the full-phrase query against
  const TEXT_FIELDS     = ['city', 'studioName', 'ownerName', 'state', 'district', 'username', 'specialties', 'about'];
  // Subset used for per-token / squash / alias clauses (highest signal fields)
  const LOCATION_FIELDS = ['city', 'studioName', 'district', 'ownerName', 'username'];

  const locOrClauses = [
    // Full-phrase match on all text fields (no `address` — encrypted)
    ...TEXT_FIELDS.map((f) => ({ [f]: { $regex: escapedLoc, $options: 'i' } })),
    { categories: { $elemMatch: { $regex: escapedLoc, $options: 'i' } } },
  ];

  // Squashed phrase variant (e.g. "thilaknagar" → matches "thilak nagar")
  if (squashedLoc && squashedLoc !== escapedLoc) {
    LOCATION_FIELDS.forEach((f) => {
      locOrClauses.push({ [f]: { $regex: squashedLoc, $options: 'i' } });
    });
  }

  // Per-token with typo patterns
  for (const token of meaningfulTokens) {
    const escapedToken = escapeRegex(token);
    const typoPattern  = fuzzySearch.buildTypoRegex(token);

    LOCATION_FIELDS.forEach((f) => {
      locOrClauses.push({ [f]: { $regex: escapedToken, $options: 'i' } });
      if (typoPattern !== escapedToken) {
        locOrClauses.push({ [f]: { $regex: typoPattern, $options: 'i' } });
      }
    });

    // City alias expansion
    const alias = fuzzySearch.CITY_ALIASES[token.toLowerCase()];
    if (alias) {
      const escapedAlias = escapeRegex(alias);
      ['city', 'district'].forEach((f) => {
        locOrClauses.push({ [f]: { $regex: escapedAlias, $options: 'i' } });
      });
    }
  }

  // Category synonym expansion
  for (const relCat of relatedCategories) {
    const escapedRel = escapeRegex(relCat);
    locOrClauses.push(
      { categories: { $elemMatch: { $regex: escapedRel, $options: 'i' } } },
      { specialties: { $regex: escapedRel, $options: 'i' } },
    );
  }

  const candidateFetchLimit = Math.max(Number(limit) * 4, 150);
  const candidateFilter = { ...baseFilter, $and: [...baseConditions, { $or: locOrClauses }] };

  let candidates = await User.find(candidateFilter).limit(candidateFetchLimit);

  // ── Fallback: broaden scope for extreme typos or address-only profiles ────
  if (candidates.length === 0) {
    const fallbackFilter = { ...baseFilter };
    if (baseConditions.length > 0) fallbackFilter.$and = baseConditions;
    candidates = await User.find(fallbackFilter).limit(Math.max(candidateFetchLimit, 200));
  }

  // ── JS fuzzy scoring — always run on every candidate ─────────────────────
  // The scorer decrypts `address` in-memory and uses it for scoring, so
  // users whose only location info is in the encrypted address are still found.
  const scored = [];
  for (const doc of candidates) {
    const score = fuzzySearch.scorePhotographerMatch(doc, loc);
    if (score > 0) scored.push({ doc, score });
  }

  scored.sort((a, b) => b.score - a.score);
  return scored.slice(0, Number(limit) || 50).map((item) => item.doc);
}

module.exports = {
  findByPhone,
  findByUsername,
  findByGoogleId,
  findByEmail,
  findById,
  createUser,
  updateUser,
  deleteUserAccount,
  searchPhotographers,
};
