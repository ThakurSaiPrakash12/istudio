const mongoose = require('mongoose');
const memoryUsers = require('../store/memoryUsers');

function hasRealMongoUri() {
  const uri = process.env.MONGODB_URI || '';
  return Boolean(
    uri &&
      !uri.includes('<username>') &&
      !uri.includes('<cluster>') &&
      !uri.includes('<password>'),
  );
}

async function connectDb() {
  if (!hasRealMongoUri()) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('MONGODB_URI is required in production.');
    }
    memoryUsers.enabled = true;
    console.warn(
      '⚠️  [DB] MongoDB URI is not set. Using IN-MEMORY store — data will NOT persist between restarts.',
    );
    return;
  }

  mongoose.set('strictQuery', true);
  await mongoose.connect(process.env.MONGODB_URI);
  const dbName = mongoose.connection.db.databaseName;
  console.log(`✅ [MONGODB] Connected to database: "${dbName}"`);
}

module.exports = { connectDb };
