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
  try {
    await mongoose.connect(process.env.MONGODB_URI);
  } catch (error) {
    // Some local resolvers (e.g. router DNS over link-local IPv6) refuse the
    // SRV lookups Node makes for mongodb+srv:// URIs. Retry once via public DNS.
    if (!(error && error.syscall === 'querySrv') && !/querySrv/.test(String(error && error.message))) {
      throw error;
    }
    logger.warn('MongoDB SRV lookup failed; retrying with public DNS servers', { error: error.message });
    require('dns').setServers(['8.8.8.8', '1.1.1.1']);
    await mongoose.connect(process.env.MONGODB_URI);
  }
  const dbName = mongoose.connection.db.databaseName;
  mongoose.connection.on('error', (error) => {
    logger.error('MongoDB connection error', error);
  });
  mongoose.connection.on('disconnected', () => {
    logger.warn('MongoDB disconnected');
  });
  logger.info('MongoDB connected', { database: dbName });

  try {
    await require('../models/User').migrateIndexes();
  } catch (error) {
    logger.error('Failed to migrate user indexes', { error: error.message });
  }
}

module.exports = { connectDb };
