const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const logger = require('../config/logger');

const dataSecurity = require('../services/dataSecurity');
const fuzzySearch = require('../utils/fuzzySearch');

const dataDir = path.join(__dirname, '..', '..', 'data');
const dataFile = path.join(dataDir, 'users.json');

function loadUsersFromDisk() {
  try {
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    if (fs.existsSync(dataFile)) {
      const content = fs.readFileSync(dataFile, 'utf8');
      const rawUsers = JSON.parse(content);
      if (Array.isArray(rawUsers)) {
        return rawUsers.map((user) => ({
          ...user,
          phone: dataSecurity.decrypt(user.phone || ''),
          email: dataSecurity.decrypt(user.email || ''),
          address: dataSecurity.decrypt(user.address || ''),
        }));
      }
    }
  } catch (e) {
    logger.warn('Could not read users.json from disk', { error: e });
  }
  return [];
}

function saveUsersToDisk(usersList) {
  try {
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    const encryptedUsers = usersList.map((user) => ({
      ...user,
      phone: user.phone || '',
      email: user.email || '',
      address: user.address ? dataSecurity.encrypt(user.address) : '',
    }));
    fs.writeFileSync(dataFile, JSON.stringify(encryptedUsers, null, 2), 'utf8');
  } catch (e) {
    logger.warn('Could not save users.json to disk', { error: e });
  }
}

const users = loadUsersFromDisk();

function publicFields(user) {
  return {
    id: user.id,
    username: user.username,
    phone: user.phone,
    studioName: user.studioName || '',
    ownerName: user.ownerName || user.username,
    email: user.email || '',
    city: user.city || '',
    state: user.state || '',
    district: user.district || '',
    address: user.address || '',
    about: user.about || '',
    instagram: user.instagram || '',
    website: user.website || '',
    specialties: user.specialties || '',
    categories: Array.isArray(user.categories) ? user.categories : [],
    latitude: typeof user.latitude === 'number' ? user.latitude : null,
    longitude: typeof user.longitude === 'number' ? user.longitude : null,
    logoUrl: user.logoUrl || '',
    paymentQrUrl: user.paymentQrUrl || '',
    googleId: user.googleId || '',
    appleId: user.appleId || '',
  };
}

function toDoc(user, withPassword = false) {
  return {
    _id: user.id,
    username: user.username,
    phone: user.phone || '',
    googleId: user.googleId || null,
    appleId: user.appleId || null,
    password: withPassword ? user.password : undefined,
    studioName: user.studioName || '',
    ownerName: user.ownerName || user.username,
    email: user.email || '',
    city: user.city || '',
      state: user.state || '',
      district: user.district || '',
    address: user.address || '',
    about: user.about || '',
    instagram: user.instagram || '',
    website: user.website || '',
    specialties: user.specialties || '',
    categories: Array.isArray(user.categories) ? user.categories : [],
    logoUrl: user.logoUrl || '',
    paymentQrUrl: user.paymentQrUrl || '',
    latitude: typeof user.latitude === 'number' ? user.latitude : null,
    longitude: typeof user.longitude === 'number' ? user.longitude : null,
    toPublicJSON() {
      return publicFields(user);
    },
  };
}

const memoryUsers = {
  enabled: false,
  findByPhone(phone, withPassword = false) {
    if (!phone) return null;
    const user = users.find((item) => item.phone === phone);
    return user ? toDoc(user, withPassword) : null;
  },
  findByUsername(username) {
    if (!username) return null;
    const user = users.find(
      (item) => item.username && item.username.toLowerCase() === username.toLowerCase(),
    );
    return user ? toDoc(user) : null;
  },
  findByGoogleId(googleId) {
    if (!googleId) return null;
    const user = users.find((item) => item.googleId === googleId);
    return user ? toDoc(user) : null;
  },
  findByAppleId(appleId) {
    if (!appleId) return null;
    const user = users.find((item) => item.appleId === appleId);
    return user ? toDoc(user) : null;
  },
  findByEmail(email) {
    if (!email) return null;
    const user = users.find(
      (item) => item.email && item.email.toLowerCase() === email.toLowerCase(),
    );
    return user ? toDoc(user) : null;
  },
  findById(id, withPassword = false) {
    const user = users.find((item) => item.id === id);
    return user ? toDoc(user, withPassword) : null;
  },
  create(data) {
    const id = data.id || data._id || randomUUID();
    const user = {
      id,
      _id: id,
      username: data.username,
      phone: data.phone || '',
      password: data.password || '',
      googleId: data.googleId || null,
      appleId: data.appleId || null,
      studioName: data.studioName || '',
      ownerName: data.ownerName || data.username,
      email: data.email || '',
      city: data.city || '',
      state: data.state || '',
      district: data.district || '',
      address: data.address || '',
      about: data.about || '',
      instagram: data.instagram || '',
      website: data.website || '',
      specialties: data.specialties || '',
      categories: Array.isArray(data.categories) ? data.categories : [],
      latitude: typeof data.latitude === 'number' ? data.latitude : null,
      longitude: typeof data.longitude === 'number' ? data.longitude : null,
      logoUrl: data.logoUrl || '',
    };
    users.push(user);
    saveUsersToDisk(users);
    return toDoc(user);
  },
  update(id, fields) {
    const user = users.find((item) => item.id === id);
    if (!user) return null;
    Object.assign(user, fields);
    saveUsersToDisk(users);
    return toDoc(user);
  },
  remove(id) {
    const index = users.findIndex((item) => item.id === id);
    if (index === -1) return false;
    users.splice(index, 1);
    saveUsersToDisk(users);
    return true;
  },
  searchPhotographers({ userId, location, query, state, district, category, categories, limit = 50, includeSelf = false }) {
    const loc = String(location || query || '').trim();
    const catList = Array.isArray(categories) && categories.length > 0
      ? categories.map((c) => String(c).toLowerCase().trim()).filter(Boolean)
      : (category && String(category).trim() ? [String(category).toLowerCase().trim()] : []);

    const uid = userId ? String(userId) : null;
    const filtered = users
      .filter((u) => includeSelf || !uid || (String(u.id) !== uid && String(u._id) !== uid))
      .filter((u) => {
        const normalized = (value) => String(value || '').trim().toLowerCase();
        if (state) {
          const uState = normalized(u.state);
          const qState = normalized(state);
          if (uState !== qState && !fuzzySearch.tokenFuzzyMatch(qState, uState)) {
            return false;
          }
        }
        if (district) {
          const uDist = normalized(u.district || u.city);
          const qDist = normalized(district);
          if (uDist !== qDist && !fuzzySearch.tokenFuzzyMatch(qDist, uDist)) {
            return false;
          }
        }
        if (catList.length > 0) {
          const userCats = Array.isArray(u.categories) ? u.categories : [];
          const userSpecs = (u.specialties || '').toLowerCase();
          const matchesAny = catList.some((catItem) => {
            return userCats.some((c) => c.toLowerCase().includes(catItem) || fuzzySearch.tokenFuzzyMatch(catItem, c.toLowerCase())) ||
                   userSpecs.includes(catItem) ||
                   fuzzySearch.tokenFuzzyMatch(catItem, userSpecs);
          });
          if (!matchesAny) return false;
        }
        return true;
      });

    if (!loc) {
      return filtered.slice(0, limit).map((u) => toDoc(u));
    }

    // Score and rank using fuzzy search
    const scored = [];
    for (const u of filtered) {
      const score = fuzzySearch.scorePhotographerMatch(u, loc);
      if (score > 0) {
        scored.push({ user: u, score });
      }
    }

    scored.sort((a, b) => b.score - a.score);
    return scored.slice(0, limit).map((item) => toDoc(item.user));
  },
};

module.exports = memoryUsers;
