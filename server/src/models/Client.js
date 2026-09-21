const mongoose = require('mongoose');

const clientSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
  name: { type: String, required: true, trim: true, maxlength: 160 },
  phone: { type: String, required: true, trim: true, maxlength: 20 },
  email: { type: String, default: '', trim: true, maxlength: 160 },
  address: { type: String, default: '', trim: true, maxlength: 300 },
  notes: { type: String, default: '', trim: true, maxlength: 1000 },
}, { timestamps: true });

clientSchema.index({ userId: 1, name: 1 });

clientSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    name: this.name,
    phone: this.phone,
    email: this.email,
    address: this.address,
    notes: this.notes,
    createdAt: this.createdAt,
  };
};

module.exports = mongoose.model('Client', clientSchema);
