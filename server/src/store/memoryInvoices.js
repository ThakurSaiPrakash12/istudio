const { randomUUID } = require('crypto');

const { invoiceTotals, toPublicInvoice } = require('../models/Invoice');

const invoices = [];

function toDoc(invoice) {
  return {
    ...invoice,
    _id: invoice.id,
    toPublicJSON() {
      return toPublicInvoice(invoice);
    },
  };
}

function nextNumberForUser(userId) {
  let max = 1000;
  const pattern = /INV-(\d+)/i;
  for (const invoice of invoices) {
    if (invoice.userId !== userId) continue;
    const match = pattern.exec(invoice.number || '');
    if (!match) continue;
    const value = Number(match[1]) || 0;
    if (value > max) max = value;
  }
  return `INV-${max + 1}`;
}

const memoryInvoices = {
  listByUser(userId) {
    return invoices
      .filter((item) => item.userId === userId)
      .sort((a, b) => new Date(b.issuedOn) - new Date(a.issuedOn))
      .map(toDoc);
  },
  listByEvent(eventId, userId) {
    return invoices
      .filter((item) => item.userId === userId && item.eventId === eventId)
      .sort((a, b) => new Date(b.issuedOn) - new Date(a.issuedOn))
      .map(toDoc);
  },
  findByIdForUser(id, userId) {
    const invoice = invoices.find(
      (item) => item.id === id && item.userId === userId,
    );
    return invoice ? toDoc(invoice) : null;
  },
  findByPaymentId(paymentId, userId) {
    const invoice = invoices.find(
      (item) => String(item.paymentId) === String(paymentId) && item.userId === userId,
    );
    return invoice ? toDoc(invoice) : null;
  },
  create(fields) {
    const deliverables = (fields.deliverables || []).map((item) => ({
      id: item.id || randomUUID(),
      name: String(item.name || '').trim(),
      cost: Number(item.cost) || 0,
    }));
    const totals = invoiceTotals(deliverables, fields.amountReceived);
    const invoice = {
      id: randomUUID(),
      userId: fields.userId,
      number: fields.number || nextNumberForUser(fields.userId),
      eventName: fields.eventName,
      contactName: fields.contactName,
      phone: fields.phone,
      address: fields.address,
      issuedOn: fields.issuedOn || new Date(),
      dueDate: fields.dueDate,
      deliverables,
      upiId: fields.upiId || '',
      amountReceived: totals.received,
      documentType: fields.documentType || 'receipt',
      eventId: fields.eventId || null,
      paymentId: fields.paymentId || null,
    };
    invoices.unshift(invoice);
    return toDoc(invoice);
  },
  update(id, userId, fields) {
    const invoice = invoices.find(
      (item) => item.id === id && item.userId === userId,
    );
    if (!invoice) return null;
    if (fields.deliverables) {
      invoice.deliverables = fields.deliverables.map((item) => ({
        id: item.id || randomUUID(),
        name: String(item.name || '').trim(),
        cost: Number(item.cost) || 0,
      }));
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
      'number',
      'eventId',
      'paymentId',
    ];
    for (const key of allowed) {
      if (fields[key] !== undefined) invoice[key] = fields[key];
    }
    const totals = invoiceTotals(invoice.deliverables, invoice.amountReceived);
    invoice.amountReceived = totals.received;
    return toDoc(invoice);
  },
  remove(id, userId) {
    const index = invoices.findIndex(
      (item) => item.id === id && item.userId === userId,
    );
    if (index === -1) return false;
    invoices.splice(index, 1);
    return true;
  },
  nextNumber(userId) {
    return nextNumberForUser(userId);
  },
};

module.exports = memoryInvoices;
