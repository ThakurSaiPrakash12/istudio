const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    username: {
      type: String,
      required: true,
      trim: true,
      minlength: 3,
      maxlength: 24,
      unique: true,
    },
    googleId: {
      type: String,
      unique: true,
      sparse: true,
      default: null,
    },
    phone: {
      type: String,
      required: function () {
        return !this.googleId;
      },
      unique: true,
      sparse: true,
      match: /^\d{10}$/,
    },
    password: {
      type: String,
      required: function () {
        return !this.googleId;
      },
      minlength: 8,
      select: false,
    },
    studioName: { type: String, default: '', trim: true },
    ownerName: { type: String, default: '', trim: true },
    email: { type: String, default: '', trim: true },
    city: { type: String, default: '', trim: true },
    address: { type: String, default: '', trim: true },
    about: { type: String, default: '', trim: true },
    instagram: { type: String, default: '', trim: true },
    youtube: { type: String, default: '', trim: true },
    website: { type: String, default: '', trim: true },
    specialties: { type: String, default: '', trim: true },
    logoUrl: { type: String, default: '' },
  },
  {
    timestamps: true,
  },
);

userSchema.methods.toPublicJSON = function toPublicJSON() {
  return {
    id: this._id.toString(),
    username: this.username,
    phone: this.phone,
    studioName: this.studioName || '',
    ownerName: this.ownerName || this.username,
    email: this.email || '',
    city: this.city || '',
    address: this.address || '',
    about: this.about || '',
    instagram: this.instagram || '',
    youtube: this.youtube || '',
    website: this.website || '',
    specialties: this.specialties || '',
    logoUrl: this.logoUrl || '',
    googleId: this.googleId || '',
  };
};

module.exports = mongoose.model('User', userSchema);
