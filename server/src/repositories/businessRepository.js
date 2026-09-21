const mongoose = require('mongoose');
const Client = require('../models/Client');
const Event = require('../models/Event');
const Payment = require('../models/Payment');
const Expense = require('../models/Expense');
const Deliverable = require('../models/Deliverable');

function validId(id) {
  return mongoose.Types.ObjectId.isValid(id);
}

function requireId(id) {
  return validId(id) ? id : null;
}

async function findClientForUser(id, userId) {
  const safeId = requireId(id);
  return safeId ? Client.findOne({ _id: safeId, userId }) : null;
}

async function findEventForUser(id, userId) {
  const safeId = requireId(id);
  return safeId ? Event.findOne({ _id: safeId, userId }) : null;
}

async function calculateEvent(event, userId) {
  const [payments, expenses, deliverables, client] = await Promise.all([
    Payment.find({ eventId: event._id, userId }).sort({ paidAt: -1, createdAt: -1 }),
    Expense.find({ eventId: event._id, userId }).sort({ incurredAt: -1, createdAt: -1 }),
    Deliverable.find({ eventId: event._id, userId }).sort({ createdAt: 1 }),
    event.clientId ? Client.findOne({ _id: event.clientId, userId }) : null,
  ]);
  const amountReceived = payments.reduce((sum, item) => sum + item.amount, 0);
  const totalExpenses = expenses.reduce((sum, item) => sum + item.amount, 0);
  const { userId: _ownerId, paymentTotal: _paymentTotal, __v: _version, ...publicEvent } = event.toObject();
  return {
    ...publicEvent,
    id: event._id.toString(),
    clientId: event.clientId ? event.clientId.toString() : null,
    clientName: client ? client.name : '',
    payments: payments.map((item) => item.toPublicJSON()),
    expenses: expenses.map((item) => item.toPublicJSON()),
    deliverables: deliverables.map((item) => item.toPublicJSON()),
    amountReceived,
    remainingAmount: Math.max(0, event.totalAmount - amountReceived),
    totalExpenses,
    netProfit: amountReceived - totalExpenses,
  };
}

async function ensurePaymentTotal(event, userId) {
  if (event.paymentTotal > 0) return event;
  const total = await Payment.aggregate([
    { $match: { eventId: event._id, userId } },
    { $group: { _id: null, total: { $sum: '$amount' } } },
  ]);
  const paymentTotal = total[0]?.total || 0;
  await Event.updateOne(
    { _id: event._id, userId, paymentTotal: { $exists: false } },
    { $set: { paymentTotal } },
  );
  event.paymentTotal = paymentTotal;
  return event;
}

async function toPublicClient(client) {
  return client.toPublicJSON();
}

async function listClients(userId) {
  return Client.find({ userId }).sort({ createdAt: -1 });
}

async function createClient(userId, fields) {
  return Client.create({ userId, ...fields });
}

async function updateClient(id, userId, fields) {
  return Client.findOneAndUpdate({ _id: requireId(id), userId }, fields, {
    new: true,
    runValidators: true,
  });
}

async function deleteClient(id, userId) {
  const client = await findClientForUser(id, userId);
  if (!client) return false;
  const linkedEvent = await Event.exists({ clientId: client._id, userId });
  if (linkedEvent) return { conflict: true };
  await client.deleteOne();
  return true;
}

async function listEvents(userId) {
  const events = await Event.find({ userId }).sort({ startsAt: 1, createdAt: -1 });
  return Promise.all(events.map((event) => calculateEvent(event, userId)));
}

async function createEvent(userId, fields) {
  if (fields.clientId) {
    const client = await findClientForUser(fields.clientId, userId);
    if (!client) return null;
  }
  const event = await Event.create({ userId, ...fields });
  return calculateEvent(event, userId);
}

async function updateEvent(id, userId, fields) {
  if (fields.clientId) {
    const client = await findClientForUser(fields.clientId, userId);
    if (!client) return null;
  }
  const event = await Event.findOneAndUpdate({ _id: requireId(id), userId }, fields, {
    new: true,
    runValidators: true,
  });
  return event ? calculateEvent(event, userId) : null;
}

async function deleteEvent(id, userId) {
  const event = await findEventForUser(id, userId);
  if (!event) return false;
  await Promise.all([
    Payment.deleteMany({ eventId: event._id, userId }),
    Expense.deleteMany({ eventId: event._id, userId }),
    Deliverable.deleteMany({ eventId: event._id, userId }),
    event.deleteOne(),
  ]);
  return true;
}

async function listPayments(eventId, userId) {
  const event = await findEventForUser(eventId, userId);
  return event ? Payment.find({ eventId: event._id, userId }).sort({ paidAt: -1 }) : null;
}

async function createPayment(eventId, userId, fields) {
  const event = await findEventForUser(eventId, userId);
  if (!event) return null;
  await ensurePaymentTotal(event, userId);
  const reserved = await Event.findOneAndUpdate(
    {
      _id: event._id,
      userId,
      $expr: {
        $lte: [
          { $add: [{ $ifNull: ['$paymentTotal', 0] }, fields.amount] },
          { $add: ['$totalAmount', 0.009] },
        ],
      },
    },
    { $inc: { paymentTotal: fields.amount } },
    { new: true },
  );
  if (!reserved) return { overpayment: true };
  try {
    return await Payment.create({ eventId: event._id, userId, ...fields });
  } catch (error) {
    await Event.updateOne({ _id: event._id, userId }, { $inc: { paymentTotal: -fields.amount } });
    throw error;
  }
}

async function updatePayment(id, userId, fields) {
  const payment = await Payment.findOne({ _id: requireId(id), userId });
  if (!payment) return null;
  const event = await findEventForUser(payment.eventId, userId);
  if (!event) return null;
  await ensurePaymentTotal(event, userId);
  const nextAmount = fields.amount ?? payment.amount;
  const delta = nextAmount - payment.amount;
  if (delta > 0) {
    const reserved = await Event.findOneAndUpdate(
      {
        _id: event._id,
        userId,
        $expr: {
          $lte: [
            { $add: [{ $ifNull: ['$paymentTotal', 0] }, delta] },
            { $add: ['$totalAmount', 0.009] },
          ],
        },
      },
      { $inc: { paymentTotal: delta } },
      { new: true },
    );
    if (!reserved) return { overpayment: true };
  } else if (delta < 0) {
    await Event.updateOne({ _id: event._id, userId }, { $inc: { paymentTotal: delta } });
  }
  try {
    Object.assign(payment, fields);
    await payment.save();
    return payment;
  } catch (error) {
    if (delta !== 0) await Event.updateOne({ _id: event._id, userId }, { $inc: { paymentTotal: -delta } });
    throw error;
  }
}

async function findPaymentForUser(id, userId) {
  const payment = await Payment.findOne({ _id: requireId(id), userId });
  if (!payment) return null;
  const event = await findEventForUser(payment.eventId, userId);
  return event ? payment : null;
}

async function findExpenseForUser(id, userId) {
  const expense = await Expense.findOne({ _id: requireId(id), userId });
  if (!expense) return null;
  const event = await findEventForUser(expense.eventId, userId);
  return event ? expense : null;
}

async function findDeliverableForUser(id, userId) {
  const deliverable = await Deliverable.findOne({ _id: requireId(id), userId });
  if (!deliverable) return null;
  const event = await findEventForUser(deliverable.eventId, userId);
  return event ? deliverable : null;
}

async function deletePayment(id, userId) {
  const payment = await Payment.findOne({ _id: requireId(id), userId });
  if (!payment) return false;
  await Event.updateOne(
    { _id: payment.eventId, userId },
    { $inc: { paymentTotal: -payment.amount } },
  );
  const result = await Payment.deleteOne({ _id: payment._id, userId });
  if (result.deletedCount !== 1) {
    await Event.updateOne({ _id: payment.eventId, userId }, { $inc: { paymentTotal: payment.amount } });
  }
  return result.deletedCount === 1;
}

async function listExpenses(eventId, userId) {
  const event = await findEventForUser(eventId, userId);
  return event ? Expense.find({ eventId: event._id, userId }).sort({ incurredAt: -1 }) : null;
}

async function createExpense(eventId, userId, fields) {
  const event = await findEventForUser(eventId, userId);
  return event ? Expense.create({ eventId: event._id, userId, ...fields }) : null;
}

async function updateExpense(id, userId, fields) {
  return Expense.findOneAndUpdate({ _id: requireId(id), userId }, fields, {
    new: true,
    runValidators: true,
  });
}

async function deleteExpense(id, userId) {
  const result = await Expense.deleteOne({ _id: requireId(id), userId });
  return result.deletedCount === 1;
}

async function listDeliverables(eventId, userId) {
  const event = await findEventForUser(eventId, userId);
  return event ? Deliverable.find({ eventId: event._id, userId }).sort({ createdAt: 1 }) : null;
}

async function createDeliverable(eventId, userId, fields) {
  const event = await findEventForUser(eventId, userId);
  return event ? Deliverable.create({ eventId: event._id, userId, ...fields }) : null;
}

async function updateDeliverable(id, userId, fields) {
  const next = { ...fields };
  if (next.isCompleted === true && !next.completedAt) next.completedAt = new Date();
  if (next.isCompleted === false) next.completedAt = null;
  return Deliverable.findOneAndUpdate({ _id: requireId(id), userId }, next, {
    new: true,
    runValidators: true,
  });
}

async function deleteDeliverable(id, userId) {
  const result = await Deliverable.deleteOne({ _id: requireId(id), userId });
  return result.deletedCount === 1;
}

module.exports = {
  findClientForUser,
  findEventForUser,
  calculateEvent,
  listClients,
  createClient,
  updateClient,
  deleteClient,
  listEvents,
  createEvent,
  updateEvent,
  deleteEvent,
  listPayments,
  createPayment,
  updatePayment,
  findPaymentForUser,
  findExpenseForUser,
  findDeliverableForUser,
  deletePayment,
  listExpenses,
  createExpense,
  updateExpense,
  deleteExpense,
  listDeliverables,
  createDeliverable,
  updateDeliverable,
  deleteDeliverable,
  toPublicClient,
};
