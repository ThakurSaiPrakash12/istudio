const mongoose = require('mongoose');

const eventSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  clientId: { type: mongoose.Schema.Types.ObjectId, ref: 'Client', required: false, index: true },
  title: { type: String, required: true, trim: true, maxlength: 200 },
  eventType: { type: String, required: true, trim: true, maxlength: 80 },
  startsAt: { type: Date, required: true, index: true },
  startTime: { type: String, default: '10:00 AM', trim: true, maxlength: 30 },
  endTime: { type: String, default: '04:00 PM', trim: true, maxlength: 30 },
  location: { type: String, required: true, trim: true, maxlength: 240 },
  status: {
    type: String,
    enum: ['upcoming', 'inProgress', 'paymentDue', 'completed', 'cancelled'],
    default: 'upcoming',
  },
  totalAmount: { type: Number, required: true, min: 0 },
  paymentTotal: { type: Number, default: 0, min: 0 },
  notes: { type: String, default: '', trim: true, maxlength: 2000 },
}, { timestamps: true });

eventSchema.index({ userId: 1, clientId: 1 });
eventSchema.index({ userId: 1, startsAt: 1 });

module.exports = mongoose.model('Event', eventSchema);
