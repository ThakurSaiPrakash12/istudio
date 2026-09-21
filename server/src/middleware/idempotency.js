const crypto = require('crypto');
const mongoose = require('mongoose');
const IdempotencyRecord = require('../models/IdempotencyRecord');

const MAX_KEY_LENGTH = 200;
const WAIT_INTERVAL_MS = 50;
const WAIT_TIMEOUT_MS = 20000;

function requestHash(req) {
  return crypto
    .createHash('sha256')
    .update(JSON.stringify(req.body || {}))
    .digest('hex');
}

function operationName(req) {
  return `${req.method}:${req.baseUrl}${req.route?.path || req.path}`;
}

async function waitForCompletion(record) {
  const startedAt = Date.now();
  let current = record;
  while (current.status === 'pending' && Date.now() - startedAt < WAIT_TIMEOUT_MS) {
    await new Promise((resolve) => setTimeout(resolve, WAIT_INTERVAL_MS));
    current = await IdempotencyRecord.findById(record._id).lean();
    if (!current) break;
  }
  return current;
}

function replay(res, record) {
  return res.status(record.statusCode || 200).json(record.responseBody || {});
}

async function idempotency(req, res, next) {
  const key = String(req.get('Idempotency-Key') || '').trim();
  if (!key) return next();
  if (key.length > MAX_KEY_LENGTH) {
    return res.status(400).json({ success: false, message: 'Idempotency-Key is too long.' });
  }
  if (mongoose.connection.readyState !== 1 || !req.userId) return next();

  const operation = operationName(req);
  const hash = requestHash(req);
  let record;
  let owner = false;
  try {
    record = await IdempotencyRecord.create({
      userId: req.userId,
      operation,
      key,
      requestHash: hash,
      status: 'pending',
    });
    owner = true;
  } catch (error) {
    if (error.code !== 11000) throw error;
    record = await IdempotencyRecord.findOne({ userId: req.userId, operation, key });
  }

  if (!record) return next();
  if (record.requestHash !== hash) {
    return res.status(409).json({
      success: false,
      message: 'Idempotency-Key was already used for a different request.',
    });
  }
  if (record.status === 'completed') return replay(res, record);

  if (!owner) {
    const completed = await waitForCompletion(record);
    if (completed?.status === 'completed') return replay(res, completed);
    return res.status(409).json({ success: false, message: 'A matching request is still in progress.' });
  }

  const originalJson = res.json.bind(res);
  res.json = async (body) => {
    await IdempotencyRecord.updateOne(
      { _id: record._id, status: 'pending' },
      { $set: { status: 'completed', statusCode: res.statusCode, responseBody: body, updatedAt: new Date() } },
    );
    return originalJson(body);
  };
  res.once('finish', () => {
    if (res.statusCode >= 500) {
      IdempotencyRecord.deleteOne({ _id: record._id, status: 'pending' }).catch(() => {});
    }
  });
  return next();
}

module.exports = { idempotency };