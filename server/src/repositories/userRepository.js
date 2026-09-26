const User = require('../models/User');
const memoryUsers = require('../store/memoryUsers');

async function findByPhone(phone, { withPassword = false } = {}) {
  if (memoryUsers.enabled) {
    return memoryUsers.findByPhone(phone, withPassword);
  }

  const query = User.findOne({ phone });
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
  return User.findOne({
    email: { $regex: new RegExp(`^${escapeRegex(email)}$`, 'i') },
  });
}

async function createUser(data) {
  const { username, phone = '', password = '', googleId = null, email = '', ownerName = '', logoUrl = '' } = data;
  if (memoryUsers.enabled) {
    return memoryUsers.create({ username, phone, password, googleId, email, ownerName: ownerName || username, logoUrl });
  }
  return User.create({
    username,
    phone: phone || undefined,
    password: password || undefined,
    googleId: googleId || undefined,
    email: email || '',
    ownerName: ownerName || username,
    logoUrl: logoUrl || '',
  });
}

async function updateUser(id, fields) {
  if (memoryUsers.enabled) {
    return memoryUsers.update(id, fields);
  }
  return User.findByIdAndUpdate(id, { $set: fields }, { new: true });
}

function escapeRegex(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

module.exports = {
  findByPhone,
  findByUsername,
  findByGoogleId,
  findByEmail,
  findById,
  createUser,
  updateUser,
};
