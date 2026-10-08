const fs = require('fs');
const path = require('path');
const repository = require('../repositories/businessRepository');
const { uploadToCloudinary } = require('../config/cloudinary');
const logger = require('../config/logger');

function validationError(req, res) {
  const { validationResult } = require('express-validator');
  const errors = validationResult(req);
  if (errors.isEmpty()) return false;
  res.status(400).json({ success: false, message: errors.array()[0].msg });
  return true;
}

function dateValue(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function fields(body, names) {
  return Object.fromEntries(names
    .filter((name) => body[name] !== undefined)
    .map((name) => [name, body[name]]));
}

const clientFields = ['name', 'phone', 'email', 'address', 'notes', 'status'];
const eventFields = ['clientId', 'title', 'eventType', 'startsAt', 'startTime', 'endTime', 'location', 'status', 'totalAmount', 'notes', 'latitude', 'longitude'];
const paymentFields = ['title', 'amount', 'paidAt', 'method', 'reference', 'proofUrl'];
const expenseFields = ['title', 'amount', 'category', 'incurredAt'];
const deliverableFields = ['stage', 'title', 'isCompleted', 'completedAt'];

async function listClients(req, res) {
  const clients = await repository.listClients(req.userId);
  return res.json({ success: true, clients: clients.map((item) => item.toPublicJSON()) });
}
async function getClient(req, res) {
  const client = await repository.findClientForUser(req.params.id, req.userId);
  if (!client) return res.status(404).json({ success: false, message: 'Client not found.' });
  return res.json({ success: true, client: client.toPublicJSON() });
}
async function createClient(req, res) {
  if (validationError(req, res)) return;
  const client = await repository.createClient(req.userId, fields(req.body, clientFields));
  return res.status(201).json({ success: true, client: client.toPublicJSON() });
}
async function updateClient(req, res) {
  if (validationError(req, res)) return;
  const client = await repository.updateClient(req.params.id, req.userId, fields(req.body, clientFields));
  if (!client) return res.status(404).json({ success: false, message: 'Client not found.' });
  return res.json({ success: true, client: client.toPublicJSON() });
}
async function deleteClient(req, res) {
  const result = await repository.deleteClient(req.params.id, req.userId);
  if (!result) return res.status(404).json({ success: false, message: 'Client not found.' });
  if (result.conflict) return res.status(409).json({ success: false, message: 'Remove the client events before deleting the client.' });
  return res.json({ success: true });
}

async function listEvents(req, res) {
  const events = await repository.listEvents(req.userId);
  return res.json({ success: true, events });
}
async function getEvent(req, res) {
  const event = await repository.findEventForUser(req.params.id, req.userId);
  if (!event) return res.status(404).json({ success: false, message: 'Event not found.' });
  return res.json({ success: true, event: await repository.calculateEvent(event, req.userId) });
}
async function createEvent(req, res) {
  if (validationError(req, res)) return;
  const body = fields(req.body, eventFields);
  body.startsAt = dateValue(body.startsAt);
  if (!body.startsAt) return res.status(400).json({ success: false, message: 'Enter a valid event date.' });
  const event = await repository.createEvent(req.userId, body);
  if (!event) return res.status(404).json({ success: false, message: 'Client not found.' });
  return res.status(201).json({ success: true, event });
}
async function updateEvent(req, res) {
  if (validationError(req, res)) return;
  const body = fields(req.body, eventFields);
  if (body.startsAt !== undefined) {
    body.startsAt = dateValue(body.startsAt);
    if (!body.startsAt) return res.status(400).json({ success: false, message: 'Enter a valid event date.' });
  }
  const event = await repository.updateEvent(req.params.id, req.userId, body);
  if (!event) return res.status(404).json({ success: false, message: 'Event not found.' });
  return res.json({ success: true, event });
}
async function deleteEvent(req, res) {
  if (!await repository.deleteEvent(req.params.id, req.userId)) return res.status(404).json({ success: false, message: 'Event not found.' });
  return res.json({ success: true });
}

function nestedList(kind, req, res) {
  return repository[`list${kind}`](req.params.eventId, req.userId).then((items) => {
    if (!items) return res.status(404).json({ success: false, message: 'Event not found.' });
    return res.json({ success: true, [kind.toLowerCase()]: items.map((item) => item.toPublicJSON()) });
  });
}
function nestedCreate(kind, fieldsList, req, res) {
  if (validationError(req, res)) return Promise.resolve();
  const body = fields(req.body, fieldsList);
  for (const key of ['paidAt', 'incurredAt']) {
    if (body[key] !== undefined) body[key] = dateValue(body[key]);
  }
  return repository[`create${kind}`](req.params.eventId, req.userId, body).then(async (item) => {
    if (!item) return res.status(404).json({ success: false, message: 'Event not found.' });
    if (item.overpayment) return res.status(400).json({ success: false, message: 'Payment cannot exceed the event total.' });
    const singular = kind.toLowerCase();

    let generatedInvoice = null;
    if (kind === 'Payment') {
      try {
        const paymentIdStr = item._id ? item._id.toString() : null;
        const invoiceRepo = require('../repositories/invoiceRepository');
        if (paymentIdStr) {
          const existingReceipt = await invoiceRepo.findByPaymentId(paymentIdStr, req.userId);
          if (existingReceipt) {
            generatedInvoice = existingReceipt;
          }
        }
        if (!generatedInvoice) {
          const event = await repository.findEventForUser(req.params.eventId, req.userId);
          if (event) {
            let clientName = 'Client';
            let clientPhone = '9999999999';
            let clientAddress = event.location || 'Studio';
            if (event.clientId) {
              const client = await repository.findClientForUser(event.clientId, req.userId);
              if (client) {
                clientName = client.name || clientName;
                clientPhone = client.phone || clientPhone;
                clientAddress = client.address || clientAddress;
              }
            }
            const userRepo = require('../repositories/userRepository');
            const user = await userRepo.findById(req.userId);
            const userPhone = user && user.phone ? user.phone : '9999999999';

            const eventDeliverables = await repository.listDeliverables(event._id, req.userId);
            const deliverables = (eventDeliverables && eventDeliverables.length > 0)
              ? eventDeliverables.map((d) => ({ name: d.title, cost: Math.max(1, Math.round(event.totalAmount / eventDeliverables.length)) }))
              : [{ name: `${event.title} (${event.eventType})`, cost: event.totalAmount || item.amount || 1 }];

            generatedInvoice = await invoiceRepo.createInvoice({
              userId: req.userId,
              eventId: event._id.toString(),
              paymentId: paymentIdStr,
              eventName: event.title,
              contactName: clientName,
              phone: clientPhone.length === 10 ? clientPhone : userPhone,
              address: clientAddress,
              dueDate: event.startsAt || new Date(),
              issuedOn: item.paidAt || new Date(),
              deliverables,
              amountReceived: event.paymentTotal || item.amount || 0,
              documentType: 'receipt',
            });
          }
        }
      } catch (_) {}
    }

    const payload = { success: true, [singular]: item.toPublicJSON() };
    if (generatedInvoice) {
      payload.invoice = generatedInvoice.toPublicJSON ? generatedInvoice.toPublicJSON() : generatedInvoice;
    }
    return res.status(201).json(payload);
  });
}
function nestedUpdate(kind, fieldsList, req, res) {
  if (validationError(req, res)) return Promise.resolve();
  const body = fields(req.body, fieldsList);
  for (const key of ['paidAt', 'incurredAt']) {
    if (body[key] !== undefined) body[key] = dateValue(body[key]);
  }
  return repository[`update${kind}`](req.params.id, req.userId, body).then((item) => {
    if (!item) return res.status(404).json({ success: false, message: `${kind.toLowerCase()} not found.` });
    if (item.overpayment) return res.status(400).json({ success: false, message: 'Payment cannot exceed the event total.' });
    return res.json({ success: true, [kind.toLowerCase()]: item.toPublicJSON() });
  });
}
async function nestedDelete(kind, req, res) {
  if (!await repository[`delete${kind}`](req.params.id, req.userId)) return res.status(404).json({ success: false, message: `${kind.toLowerCase()} not found.` });
  return res.json({ success: true });
}

const listPayments = (req, res) => nestedList('Payments', req, res);
const createPayment = (req, res) => nestedCreate('Payment', paymentFields, req, res);
const updatePayment = (req, res) => nestedUpdate('Payment', paymentFields, req, res);
const deletePayment = (req, res) => nestedDelete('Payment', req, res);
async function getPayment(req, res) {
  const item = await repository.findPaymentForUser(req.params.id, req.userId);
  if (!item) return res.status(404).json({ success: false, message: 'Payment not found.' });
  return res.json({ success: true, payment: item.toPublicJSON() });
}

async function uploadPaymentProof(req, res) {
  const payment = await repository.findPaymentForUser(req.params.id, req.userId);
  if (!payment) return res.status(404).json({ success: false, message: 'Payment not found.' });
  if (!req.file) return res.status(400).json({ success: false, message: 'Choose a payment proof image or PDF.' });
  try {
    const isPdf = path.extname(req.file.originalname || '').toLowerCase() === '.pdf' ||
      req.file.mimetype === 'application/pdf';
    const uploadOptions = {
      folder: `lumen_studio/payments/${req.userId}`,
      resource_type: isPdf ? 'raw' : 'auto',
    };
    if (!isPdf) {
      uploadOptions.transformation = [{ quality: 'auto' }];
    }
    const result = await uploadToCloudinary(req.file.path, uploadOptions);
    if (!result.secure_url || !result.secure_url.startsWith('https://')) {
      return res.status(500).json({ success: false, message: 'Payment proof upload failed.' });
    }
    const updated = await repository.updatePayment(req.params.id, req.userId, {
      proofUrl: result.secure_url,
    });
    return res.json({ success: true, payment: updated.toPublicJSON() });
  } catch (error) {
    logger.error('Payment proof upload error', logger.fromRequest(req, error));
    return res.status(500).json({ success: false, message: 'Unable to upload payment proof.' });
  }
}

async function removePaymentProof(req, res) {
  const updated = await repository.updatePayment(req.params.id, req.userId, { proofUrl: '' });
  if (!updated) return res.status(404).json({ success: false, message: 'Payment not found.' });
  return res.json({ success: true, payment: updated.toPublicJSON() });
}

async function authorizePaymentProof(req, res, next) {
  const payment = await repository.findPaymentForUser(req.params.id, req.userId);
  if (!payment) return res.status(404).json({ success: false, message: 'Payment not found.' });
  req.payment = payment;
  return next();
}
const listExpenses = (req, res) => nestedList('Expenses', req, res);
const createExpense = (req, res) => nestedCreate('Expense', expenseFields, req, res);
const updateExpense = (req, res) => nestedUpdate('Expense', expenseFields, req, res);
const deleteExpense = (req, res) => nestedDelete('Expense', req, res);
async function getExpense(req, res) {
  const item = await repository.findExpenseForUser(req.params.id, req.userId);
  if (!item) return res.status(404).json({ success: false, message: 'Expense not found.' });
  return res.json({ success: true, expense: item.toPublicJSON() });
}
const listDeliverables = (req, res) => nestedList('Deliverables', req, res);
const createDeliverable = (req, res) => nestedCreate('Deliverable', deliverableFields, req, res);
const updateDeliverable = (req, res) => nestedUpdate('Deliverable', deliverableFields, req, res);
const deleteDeliverable = (req, res) => nestedDelete('Deliverable', req, res);
async function getDeliverable(req, res) {
  const item = await repository.findDeliverableForUser(req.params.id, req.userId);
  if (!item) return res.status(404).json({ success: false, message: 'Deliverable not found.' });
  return res.json({ success: true, deliverable: item.toPublicJSON() });
}

async function autoGenerateInvoice(req, res) {
  try {
    const eventId = req.params.eventId || req.params.id;
    const event = await repository.findEventForUser(eventId, req.userId);
    if (!event) return res.status(404).json({ success: false, message: 'Event not found.' });

    const invoiceRepo = require('../repositories/invoiceRepository');
    const existing = await invoiceRepo.listByEvent(event._id.toString(), req.userId);
    if (existing && existing.length > 0) {
      return res.json({
        success: true,
        invoice: existing[0].toPublicJSON(),
        invoices: existing.map((i) => i.toPublicJSON()),
        isNew: false,
      });
    }

    let clientName = 'Client';
    let clientPhone = '9999999999';
    let clientAddress = event.location || 'Studio';
    if (event.clientId) {
      const client = await repository.findClientForUser(event.clientId, req.userId);
      if (client) {
        clientName = client.name || clientName;
        clientPhone = client.phone || clientPhone;
        clientAddress = client.address || clientAddress;
      }
    }
    const userRepo = require('../repositories/userRepository');
    const user = await userRepo.findById(req.userId);
    const userPhone = user && user.phone ? user.phone : '9999999999';

    const eventDeliverables = await repository.listDeliverables(event._id, req.userId);
    const deliverables = (eventDeliverables && eventDeliverables.length > 0)
      ? eventDeliverables.map((d) => ({ name: d.title, cost: Math.max(1, Math.round(event.totalAmount / eventDeliverables.length)) }))
      : [{ name: `${event.title} (${event.eventType})`, cost: event.totalAmount || 1 }];

    const created = await invoiceRepo.createInvoice({
      userId: req.userId,
      eventId: event._id.toString(),
      eventName: event.title,
      contactName: clientName,
      phone: clientPhone.length === 10 ? clientPhone : userPhone,
      address: clientAddress,
      dueDate: event.startsAt || new Date(),
      issuedOn: new Date(),
      deliverables,
      amountReceived: event.paymentTotal || 0,
      documentType: 'receipt',
    });

    return res.status(201).json({
      success: true,
      invoice: created.toPublicJSON(),
      invoices: [created.toPublicJSON()],
      isNew: true,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Unable to auto-create invoice for this event.',
    });
  }
}

module.exports = {
  listClients, getClient, createClient, updateClient, deleteClient,
  listEvents, getEvent, createEvent, updateEvent, deleteEvent,
  listPayments, getPayment, createPayment, updatePayment, deletePayment,
  uploadPaymentProof, removePaymentProof, authorizePaymentProof,
  listExpenses, getExpense, createExpense, updateExpense, deleteExpense,
  listDeliverables, getDeliverable, createDeliverable, updateDeliverable, deleteDeliverable,
  autoGenerateInvoice,
};
