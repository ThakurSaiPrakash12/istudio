const mongoose = require('mongoose');

const deliverableSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  eventId: { type: mongoose.Schema.Types.ObjectId, ref: 'Event', required: true, index: true },
  stage: { type: String, default: 'General', trim: true, maxlength: 100 },
  title: { type: String, required: true, trim: true, maxlength: 200 },
  isCompleted: { type: Boolean, default: false },
  completedAt: { type: Date, default: null },
}, { timestamps: true });

deliverableSchema.index({ userId: 1, eventId: 1 });

deliverableSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    title: this.title,
    stage: this.stage,
    isCompleted: this.isCompleted,
    completedAt: this.completedAt,
  };
};

module.exports = mongoose.model('Deliverable', deliverableSchema);
