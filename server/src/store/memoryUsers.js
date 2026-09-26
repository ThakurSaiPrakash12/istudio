const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');
const logger = require('../config/logger');

const dataDir = path.join(__dirname, '..', '..', 'data');
const dataFile = path.join(dataDir, 'users.json');

function loadUsersFromDisk() {
  try {
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    if (fs.existsSync(dataFile)) {
      const content = fs.readFileSync(dataFile, 'utf8');
      return JSON.parse(content);
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
    fs.writeFileSync(dataFile, JSON.stringify(usersList, null, 2), 'utf8');
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
    logoUrl: user.logoUrl || '',
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
    logoUrl: user.logoUrl || '',
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
};

module.exports = memoryUsers;
