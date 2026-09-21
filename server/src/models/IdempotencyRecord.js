const mongoose = require('mongoose');

const idempotencyRecordSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, required: true, index: true },
  operation: { type: String, required: true },
  key: { type: String, required: true },
  requestHash: { type: String, required: true },
  status: { type: String, enum: ['pending', 'completed'], default: 'pending' },
  statusCode: { type: Number },
  responseBody: { type: mongoose.Schema.Types.Mixed },
  updatedAt: { type: Date, default: Date.now },
}, { timestamps: true });

idempotencyRecordSchema.index(
  { userId: 1, operation: 1, key: 1 },
  { unique: true },
);

module.exports = mongoose.model('IdempotencyRecord', idempotencyRecordSchema);