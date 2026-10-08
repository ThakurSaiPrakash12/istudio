const mongoose = require('mongoose');
const dataSecurity = require('../services/dataSecurity');

function invoiceTotals(deliverables = [], amountReceived = 0) {
  const total = deliverables.reduce(
    (sum, item) => sum + Number(item.cost || 0),
    0,
  );
  const received = Math.min(Math.max(Number(amountReceived) || 0, 0), total);
  const pendingRaw = total - received;
  const pending = pendingRaw < 0.01 ? 0 : pendingRaw;
  return { total, received, pending };
}

function invoiceStatus(dueDate, totals) {
  if (totals.pending <= 0) return 'paid';
  const due = new Date(dueDate);
  const dueEnd = new Date(
    due.getFullYear(),
    due.getMonth(),
    due.getDate(),
    23,
    59,
    59,
    999,
  );
  if (Date.now() > dueEnd.getTime()) return 'overdue';
  if (totals.received > 0.009) return 'partial';
  return 'pending';
}

function toPublicInvoice(doc) {
  const deliverables = (doc.deliverables || []).map((item) => ({
    id: item.id || '',
    name: item.name || '',
    cost: Number(item.cost) || 0,
  }));
  const totals = invoiceTotals(deliverables, doc.amountReceived);
  const issuedOn = doc.issuedOn ? new Date(doc.issuedOn) : new Date();
  const dueDate = doc.dueDate ? new Date(doc.dueDate) : issuedOn;

  const plainPhone = dataSecurity.decrypt(doc.phone || '');
  return {
    id: doc.id || (doc._id ? doc._id.toString() : ''),
    number: doc.number || '',
    eventName: doc.eventName || '',
    contactName: doc.contactName || '',
    phone: plainPhone,
    maskedPhone: dataSecurity.maskPhone(plainPhone),
    address: dataSecurity.decrypt(doc.address || ''),
    issuedOn: issuedOn.toISOString(),
    dueDate: dueDate.toISOString(),
    deliverables,
    upiId: dataSecurity.decrypt(doc.upiId || ''),
    amountReceived: totals.received,
    documentType: doc.documentType || 'receipt',
    eventId: doc.eventId ? doc.eventId.toString() : '',
    paymentId: doc.paymentId ? doc.paymentId.toString() : '',
    total: totals.total,
    pendingAmount: totals.pending,
    status: invoiceStatus(dueDate, totals),
  };
}

const deliverableSchema = new mongoose.Schema(
  {
    id: { type: String, default: '' },
    name: { type: String, required: true, trim: true },
    cost: { type: Number, required: true, min: 0 },
  },
  { _id: false },
);

const invoiceSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    number: { type: String, required: true, trim: true },
    eventName: { type: String, required: true, trim: true },
    contactName: { type: String, required: true, trim: true },
    phone: { type: String, required: true, trim: true },
    address: { type: String, required: true, trim: true },
    issuedOn: { type: Date, required: true, default: Date.now },
    dueDate: { type: Date, required: true },
    deliverables: { type: [deliverableSchema], default: [] },
    upiId: { type: String, default: '', trim: true },
    amountReceived: { type: Number, default: 0, min: 0 },
    documentType: {
      type: String,
      enum: ['receipt', 'estimate'],
      default: 'receipt',
      index: true,
    },
    eventId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Event',
      default: null,
      index: true,
    },
    paymentId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Payment',
      default: null,
    },
  },
  { timestamps: true },
);

invoiceSchema.index({ userId: 1, number: 1 }, { unique: true });
invoiceSchema.index({ userId: 1, issuedOn: -1 });

invoiceSchema.plugin(dataSecurity.encryptedFieldsPlugin, {
  deterministicFields: [],
  fields: ['address', 'upiId'],
});

invoiceSchema.methods.toPublicJSON = function toPublicJSON() {
  return toPublicInvoice(this);
};

module.exports = {
  Invoice: mongoose.model('Invoice', invoiceSchema),
  invoiceTotals,
  invoiceStatus,
  toPublicInvoice,
};
