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

async function createUser({ username, phone, password }) {
  if (memoryUsers.enabled) {
    return memoryUsers.create({ username, phone, password });
  }
  return User.create({ username, phone, password, ownerName: username });
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
  findById,
  createUser,
  updateUser,
};
