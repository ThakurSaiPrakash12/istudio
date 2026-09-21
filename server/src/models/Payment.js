const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true, index: true },
  title: { type: String, required: true, trim: true, maxlength: 160 },
  amount: { type: Number, required: true, min: 0.01 },
  paidAt: { type: Date, required: true },
  method: { type: String, enum: ['cash', 'upi', 'bankTransfer', 'card', 'other'], required: true },
  reference: { type: String, default: '', trim: true, maxlength: 160 },
  proofUrl: { type: String, default: '', trim: true },
}, { timestamps: true });

paymentSchema.index({ userId: 1, eventId: 1, paidAt: -1 });

paymentSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    title: this.title,
    amount: this.amount,
    paidAt: this.paidAt,
    method: this.method,
    reference: this.reference,
    proof: this.proofUrl || null,
  };
};

module.exports = mongoose.model('Payment', paymentSchema);
