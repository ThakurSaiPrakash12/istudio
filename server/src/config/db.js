const mongoose = require('mongoose');
const memoryUsers = require('../store/memoryUsers');
const logger = require('./logger');

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
    logger.warn('MongoDB URI is not set; using in-memory store. Data will not persist between restarts.');
    return;
  }

  mongoose.set('strictQuery', true);
  await mongoose.connect(process.env.MONGODB_URI);
  const dbName = mongoose.connection.db.databaseName;
  mongoose.connection.on('error', (error) => {
    logger.error('MongoDB connection error', error);
  });
  mongoose.connection.on('disconnected', () => {
    logger.warn('MongoDB disconnected');
  });
  logger.info('MongoDB connected', { database: dbName });
}

module.exports = { connectDb };
