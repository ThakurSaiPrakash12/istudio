const fs = require('fs');
const path = require('path');
const { randomUUID } = require('crypto');

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
    console.warn('Could not read users.json from disk:', e.message);
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
    console.warn('Could not save users.json to disk:', e.message);
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
  };
}

function toDoc(user, withPassword = false) {
  return {
    _id: user.id,
    username: user.username,
    phone: user.phone,
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
    const user = users.find((item) => item.phone === phone);
    return user ? toDoc(user, withPassword) : null;
  },
  findByUsername(username) {
    const user = users.find(
      (item) => item.username.toLowerCase() === username.toLowerCase(),
    );
    return user ? toDoc(user) : null;
  },
  findById(id) {
    const user = users.find((item) => item.id === id);
    return user ? toDoc(user) : null;
  },
  create({ username, phone, password }) {
    const user = {
      id: randomUUID(),
      username,
      phone,
      password,
      studioName: '',
      ownerName: username,
      email: '',
      city: '',
      address: '',
      about: '',
      instagram: '',
      website: '',
      specialties: '',
      logoUrl: '',
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
