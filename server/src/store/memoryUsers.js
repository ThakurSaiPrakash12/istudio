const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const logger = require('../config/logger');

const dataSecurity = require('../services/dataSecurity');

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
  };
}

function toDoc(user, withPassword = false) {
  return {
    _id: user.id,
    username: user.username,
    phone: user.phone || '',
    googleId: user.googleId || null,
    password: withPassword ? user.password : undefined,
    studioName: user.studioName || '',
    ownerName: user.ownerName || user.username,
    email: user.email || '',
    city: user.city || '',
    address: user.address || '',
    about: user.about || '',
    instagram: user.instagram || '',
    website: user.website || '',
    specialties: user.specialties || '',
    categories: Array.isArray(user.categories) ? user.categories : [],
    logoUrl: user.logoUrl || '',
    paymentQrUrl: user.paymentQrUrl || '',
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
    const user = {
      id: randomUUID(),
      username: data.username,
      phone: data.phone || '',
      password: data.password || '',
      googleId: data.googleId || null,
      studioName: data.studioName || '',
      ownerName: data.ownerName || data.username,
      email: data.email || '',
      city: data.city || '',
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
  searchPhotographers({ userId, location, query, category, limit = 50 }) {
    const locLower = String(location || query || '').toLowerCase().trim();
    const catLower = String(category || '').toLowerCase().trim();
    return users
      .filter((u) => u.id !== userId)
      .filter((u) => {
        if (locLower) {
          const matchCity = (u.city || '').toLowerCase().includes(locLower);
          const matchAddress = (u.address || '').toLowerCase().includes(locLower);
          const matchStudio = (u.studioName || '').toLowerCase().includes(locLower);
          const matchOwner = (u.ownerName || '').toLowerCase().includes(locLower);
          if (!matchCity && !matchAddress && !matchStudio && !matchOwner) return false;
        }
        if (catLower) {
          const cats = Array.isArray(u.categories) ? u.categories : [];
          const matchCat = cats.some((c) => c.toLowerCase().includes(catLower));
          const matchSpec = (u.specialties || '').toLowerCase().includes(catLower);
          if (!matchCat && !matchSpec) return false;
        }
        return true;
      })
      .slice(0, limit)
      .map((u) => toDoc(u));
  },
};

module.exports = memoryUsers;
