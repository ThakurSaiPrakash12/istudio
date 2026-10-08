const mongoose = require('mongoose');
const dataSecurity = require('../services/dataSecurity');

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
      default: null,
    },
    phone: {
      type: String,
      required: false,
      default: '',
      validate: {
        validator: function (v) {
          if (!v) return true;
          return /^\d{10}$/.test(v);
        },
        message: 'Phone number must be a valid 10-digit number',
      },
    },
    password: {
      type: String,
      required: false,
      minlength: 8,
      select: false,
    },
    studioName: { type: String, default: '', trim: true },
    ownerName: { type: String, default: '', trim: true },
    email: { type: String, default: '', trim: true, lowercase: true, index: true },
    city: { type: String, default: '', trim: true },
    address: { type: String, default: '', trim: true },
    about: { type: String, default: '', trim: true },
    instagram: { type: String, default: '', trim: true },
    youtube: { type: String, default: '', trim: true },
    website: { type: String, default: '', trim: true },
    specialties: { type: String, default: '', trim: true },
    categories: { type: [String], default: [] },
    latitude: { type: Number, default: null },
    longitude: { type: Number, default: null },
    logoUrl: { type: String, default: '' },
    paymentQrUrl: { type: String, default: '' },
  },
  {
    timestamps: true,
  },
);

// Partial indexes: Google-only users have no phone and phone users have no
// googleId, so empty/null values must not count towards uniqueness.
userSchema.index(
  { phone: 1 },
  { unique: true, partialFilterExpression: { phone: { $type: 'string', $gt: '' } } },
);
userSchema.index(
  { googleId: 1 },
  { unique: true, partialFilterExpression: { googleId: { $type: 'string', $gt: '' } } },
);

userSchema.statics.migrateIndexes = async function migrateIndexes() {
  let existing = [];
  try {
    existing = await this.collection.indexes();
  } catch (error) {
    if (error.codeName !== 'NamespaceNotFound') throw error;
  }
  for (const name of ['phone_1', 'googleId_1']) {
    const index = existing.find((item) => item.name === name);
    if (index && !index.partialFilterExpression) {
      await this.collection.dropIndex(name);
    }
  }
  await this.createIndexes();
};

userSchema.plugin(dataSecurity.encryptedFieldsPlugin, {
  deterministicFields: [],
  fields: ['address'],
});

userSchema.methods.toPublicJSON = function toPublicJSON() {
  // Phone and email are stored as plain text. dataSecurity.decrypt is
  // backwards-compatible: plain values pass through unchanged.
  const plainPhone = dataSecurity.decrypt(this.phone || '');
  const plainEmail = dataSecurity.decrypt(this.email || '');
  return {
    id: this._id.toString(),
    username: this.username,
    phone: plainPhone,
    maskedPhone: dataSecurity.maskPhone(plainPhone),
    studioName: this.studioName || '',
    ownerName: this.ownerName || this.username,
    email: plainEmail,
    maskedEmail: dataSecurity.maskEmail(plainEmail),
    city: this.city || '',
    address: dataSecurity.decrypt(this.address || ''),
    about: this.about || '',
    instagram: this.instagram || '',
    youtube: this.youtube || '',
    website: this.website || '',
    specialties: this.specialties || '',
    categories: Array.isArray(this.categories) ? this.categories : [],
    latitude: typeof this.latitude === 'number' ? this.latitude : null,
    longitude: typeof this.longitude === 'number' ? this.longitude : null,
    logoUrl: this.logoUrl || '',
    paymentQrUrl: this.paymentQrUrl || '',
    googleId: this.googleId || '',
  };
};

module.exports = mongoose.model('User', userSchema);
