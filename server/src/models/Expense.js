const mongoose = require('mongoose');

const expenseSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true, index: true },
  title: { type: String, required: true, trim: true, maxlength: 160 },
  amount: { type: Number, required: true, min: 0.01 },
  category: { type: String, required: true, trim: true, maxlength: 100 },
  incurredAt: { type: Date, required: true },
}, { timestamps: true });

expenseSchema.index({ userId: 1, eventId: 1, incurredAt: -1 });

expenseSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    title: this.title,
    amount: this.amount,
    category: this.category,
    incurredAt: this.incurredAt,
  };
};

module.exports = mongoose.model('Expense', expenseSchema);
