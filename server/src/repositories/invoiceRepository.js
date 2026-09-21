const { randomUUID } = require('crypto');
const mongoose = require('mongoose');

const { Invoice, invoiceTotals } = require('../models/Invoice');
const memoryUsers = require('../store/memoryUsers');
const memoryInvoices = require('../store/memoryInvoices');

function usesMemory() {
  return memoryUsers.enabled;
}

function normalizeDeliverables(items = []) {
  return items.map((item) => ({
    id: String(item.id || randomUUID()),
    name: String(item.name || '').trim(),
    cost: Number(item.cost) || 0,
  }));
}

async function listByUser(userId) {
  if (usesMemory()) {
    return memoryInvoices.listByUser(userId);
  }
  return Invoice.find({ userId }).sort({ issuedOn: -1, createdAt: -1 });
}

async function findByIdForUser(id, userId) {
  if (usesMemory()) {
    return memoryInvoices.findByIdForUser(id, userId);
  }
  if (!mongoose.Types.ObjectId.isValid(id)) return null;
  const invoice = await Invoice.findById(id);
  if (!invoice || invoice.userId.toString() !== String(userId)) return null;
  return invoice;
}

async function nextNumber(userId) {
  if (usesMemory()) {
    return memoryInvoices.nextNumber(userId);
  }

  const invoices = await Invoice.find({ userId }).select('number').lean();
  let max = 1000;
  const pattern = /INV-(\d+)/i;
  for (const invoice of invoices) {
    const match = pattern.exec(invoice.number || '');
    if (!match) continue;
    const value = Number(match[1]) || 0;
    if (value > max) max = value;
  }
  return `INV-${max + 1}`;
}

async function createInvoice(fields) {
  const deliverables = normalizeDeliverables(fields.deliverables);
  const totals = invoiceTotals(deliverables, fields.amountReceived);
  const payload = {
    userId: fields.userId,
    number: fields.number || (await nextNumber(fields.userId)),
    eventName: fields.eventName,
    contactName: fields.contactName,
    phone: fields.phone,
    address: fields.address,
    issuedOn: fields.issuedOn || new Date(),
    dueDate: fields.dueDate,
    deliverables,
    upiId: fields.upiId || '',
    amountReceived: totals.received,
  };

  if (usesMemory()) {
    return memoryInvoices.create(payload);
  }
  return Invoice.create(payload);
}

async function updateInvoice(id, userId, fields) {
  if (usesMemory()) {
    const next = { ...fields };
    if (fields.deliverables) {
      next.deliverables = normalizeDeliverables(fields.deliverables);
    }
    if (fields.amountReceived !== undefined || fields.deliverables) {
      const current = memoryInvoices.findByIdForUser(id, userId);
      if (!current) return null;
      const deliverables = next.deliverables || current.deliverables;
      const amount =
        fields.amountReceived !== undefined
          ? fields.amountReceived
          : current.amountReceived;
      const totals = invoiceTotals(deliverables, amount);
      next.amountReceived = totals.received;
    }
    return memoryInvoices.update(id, userId, next);
  }

  const allowed = [
    'eventName',
    'contactName',
    'phone',
    'address',
    'issuedOn',
    'dueDate',
    'upiId',
    'amountReceived',
  ];
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const invoice = await findByIdForUser(id, userId);
    if (!invoice) return null;
    const deliverables = fields.deliverables
      ? normalizeDeliverables(fields.deliverables)
      : invoice.deliverables;
    const nextFields = {};
    for (const key of allowed) {
      if (fields[key] !== undefined) nextFields[key] = fields[key];
    }
    const totals = invoiceTotals(
      deliverables,
      fields.amountReceived !== undefined
        ? fields.amountReceived
        : invoice.amountReceived,
    );
    nextFields.amountReceived = totals.received;
    if (fields.deliverables) nextFields.deliverables = deliverables;
    const updated = await Invoice.findOneAndUpdate(
      { _id: invoice._id, userId, __v: invoice.__v || 0 },
      { $set: nextFields, $inc: { __v: 1 } },
      { new: true, runValidators: true },
    );
    if (updated) return updated;
  }
  throw new Error('Invoice was changed concurrently. Please retry.');
}

async function addPartialPayment(id, userId, amount) {
  if (usesMemory()) {
    const invoice = memoryInvoices.findByIdForUser(id, userId);
    if (!invoice) return null;
    const totals = invoiceTotals(invoice.deliverables, invoice.amountReceived);
    if (amount > totals.pending + 0.009) return { overpayment: true };
    return memoryInvoices.update(id, userId, {
      amountReceived: totals.received + amount,
    });
  }
  const updated = await Invoice.findOneAndUpdate(
    {
      _id: id,
      userId,
      $expr: {
        $lte: [
          { $add: [{ $ifNull: ['$amountReceived', 0] }, amount] },
          { $sum: '$deliverables.cost' },
        ],
      },
    },
    { $inc: { amountReceived: amount } },
    { new: true, runValidators: true },
  );
  return updated || { overpayment: true };
}

async function markPaidAtomic(id, userId) {
  if (usesMemory()) {
    const invoice = memoryInvoices.findByIdForUser(id, userId);
    if (!invoice) return null;
    return memoryInvoices.update(id, userId, {
      amountReceived: invoiceTotals(invoice.deliverables).total,
    });
  }
  for (let attempt = 0; attempt < 3; attempt += 1) {
    const invoice = await findByIdForUser(id, userId);
    if (!invoice) return null;
    const total = invoiceTotals(invoice.deliverables).total;
    const updated = await Invoice.findOneAndUpdate(
      { _id: invoice._id, userId, __v: invoice.__v || 0 },
      { $set: { amountReceived: total }, $inc: { __v: 1 } },
      { new: true, runValidators: true },
    );
    if (updated) return updated;
  }
  throw new Error('Invoice was changed concurrently. Please retry.');
}

async function deleteInvoice(id, userId) {
  if (usesMemory()) {
    return memoryInvoices.remove(id, userId);
  }
  const invoice = await findByIdForUser(id, userId);
  if (!invoice) return false;
  await invoice.deleteOne();
  return true;
}

module.exports = {
  listByUser,
  findByIdForUser,
  nextNumber,
  createInvoice,
  updateInvoice,
  addPartialPayment,
  markPaidAtomic,
  deleteInvoice,
};
