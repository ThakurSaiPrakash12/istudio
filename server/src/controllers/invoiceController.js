const { randomUUID } = require('crypto');
const { validationResult } = require('express-validator');

const { normalizePhone } = require('./authController');
const { invoiceTotals } = require('../models/Invoice');
const invoiceRepository = require('../repositories/invoiceRepository');

function sendValidationError(req, res) {
  const errors = validationResult(req);
  if (errors.isEmpty()) return false;
  return res.status(400).json({
    success: false,
    message: errors.array()[0].msg,
  });
}

function parseDate(value) {
  if (!value) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function overviewFrom(invoices) {
  let total = 0;
  let received = 0;
  for (const invoice of invoices) {
    const json = invoice.toPublicJSON();
    total += json.total;
    received += json.amountReceived;
  }
  return {
    total,
    received,
    pending: Math.max(0, total - received),
  };
}

function matchesFilter(json, filter) {
  switch (filter) {
    case 'paid':
      return json.status === 'paid';
    case 'pending':
      return json.status === 'pending';
    case 'partial':
      return json.amountReceived > 0.009 && json.pendingAmount > 0;
    case 'overdue':
      return json.status === 'overdue';
    default:
      return true;
  }
}

async function listInvoices(req, res) {
  try {
    const invoices = await invoiceRepository.listByUser(req.userId);
    const publicInvoices = invoices.map((invoice) => invoice.toPublicJSON());
    const filter = String(req.query.filter || 'all').toLowerCase();
    const filtered =
      filter && filter !== 'all'
        ? publicInvoices.filter((item) => matchesFilter(item, filter))
        : publicInvoices;

    return res.json({
      success: true,
      invoices: filtered,
      overview: overviewFrom(invoices),
      nextNumber: await invoiceRepository.nextNumber(req.userId),
    });
  } catch (error) {
    console.error('List invoices error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to load invoices right now.',
    });
  }
}

async function getInvoice(req, res) {
  try {
    const invoice = await invoiceRepository.findByIdForUser(
      req.params.id,
      req.userId,
    );
    if (!invoice) {
      return res.status(404).json({
        success: false,
        message: 'Invoice not found.',
      });
    }
    return res.json({
      success: true,
      invoice: invoice.toPublicJSON(),
    });
  } catch (error) {
    console.error('Get invoice error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to load that invoice.',
    });
  }
}

function readInvoiceFields(body) {
  const deliverables = Array.isArray(body.deliverables)
    ? body.deliverables.map((item) => ({
        id: String(item.id || randomUUID()),
        name: String(item.name || '').trim(),
        cost: Number(item.cost) || 0,
      }))
    : [];

  return {
    eventName: String(body.eventName || '').trim(),
    contactName: String(body.contactName || '').trim(),
    phone: normalizePhone(body.phone),
    address: String(body.address || '').trim(),
    issuedOn: parseDate(body.issuedOn) || new Date(),
    dueDate: parseDate(body.dueDate),
    deliverables,
    upiId: String(body.upiId || '').trim(),
    amountReceived: Number(body.amountReceived) || 0,
  };
}

async function createInvoice(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const fields = readInvoiceFields(req.body);
    if (!fields.dueDate) {
      return res.status(400).json({
        success: false,
        message: 'Choose a due date for this invoice.',
      });
    }
    if (fields.deliverables.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'Add at least one deliverable.',
      });
    }
    if (fields.deliverables.some((item) => !item.name || item.cost <= 0)) {
      return res.status(400).json({
        success: false,
        message: 'Each deliverable needs a name and a cost greater than 0.',
      });
    }
    if (fields.amountReceived > invoiceTotals(fields.deliverables).total) {
      return res.status(400).json({
        success: false,
        message: 'Amount received cannot exceed the invoice total.',
      });
    }
    if (fields.phone.length !== 10) {
      return res.status(400).json({
        success: false,
        message: 'Enter a valid 10-digit phone number.',
      });
    }

    const invoice = await invoiceRepository.createInvoice({
      ...fields,
      userId: req.userId,
    });

    return res.status(201).json({
      success: true,
      invoice: invoice.toPublicJSON(),
    });
  } catch (error) {
    if (error && error.code === 11000) {
      return res.status(409).json({
        success: false,
        message: 'An invoice with that number already exists.',
      });
    }
    console.error('Create invoice error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to create the invoice right now.',
    });
  }
}

async function updateInvoice(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const current = await invoiceRepository.findByIdForUser(
      req.params.id,
      req.userId,
    );
    if (!current) {
      return res.status(404).json({
        success: false,
        message: 'Invoice not found.',
      });
    }

    const fields = {};
    const body = req.body || {};
    if (body.eventName !== undefined) fields.eventName = String(body.eventName).trim();
    if (body.contactName !== undefined) {
      fields.contactName = String(body.contactName).trim();
    }
    if (body.phone !== undefined) {
      const phone = normalizePhone(body.phone);
      if (phone.length !== 10) {
        return res.status(400).json({
          success: false,
          message: 'Enter a valid 10-digit phone number.',
        });
      }
      fields.phone = phone;
    }
    if (body.address !== undefined) fields.address = String(body.address).trim();
    if (body.upiId !== undefined) fields.upiId = String(body.upiId).trim();
    if (body.dueDate !== undefined) {
      const dueDate = parseDate(body.dueDate);
      if (!dueDate) {
        return res.status(400).json({
          success: false,
          message: 'Enter a valid due date.',
        });
      }
      fields.dueDate = dueDate;
    }
    if (body.issuedOn !== undefined) {
      const issuedOn = parseDate(body.issuedOn);
      if (issuedOn) fields.issuedOn = issuedOn;
    }
    if (Array.isArray(body.deliverables)) {
      fields.deliverables = body.deliverables.map((item) => ({
        id: String(item.id || randomUUID()),
        name: String(item.name || '').trim(),
        cost: Number(item.cost) || 0,
      }));
    }
    if (body.amountReceived !== undefined) {
      fields.amountReceived = Number(body.amountReceived) || 0;
    }

    const nextDeliverables = fields.deliverables || current.deliverables;
    if (fields.amountReceived !== undefined &&
        fields.amountReceived > invoiceTotals(nextDeliverables).total) {
      return res.status(400).json({
        success: false,
        message: 'Amount received cannot exceed the invoice total.',
      });
    }

    const invoice = await invoiceRepository.updateInvoice(
      req.params.id,
      req.userId,
      fields,
    );
    return res.json({
      success: true,
      invoice: invoice.toPublicJSON(),
    });
  } catch (error) {
    console.error('Update invoice error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to update the invoice right now.',
    });
  }
}

async function deleteInvoice(req, res) {
  try {
    const removed = await invoiceRepository.deleteInvoice(
      req.params.id,
      req.userId,
    );
    if (!removed) {
      return res.status(404).json({
        success: false,
        message: 'Invoice not found.',
      });
    }
    return res.json({
      success: true,
      message: 'Invoice deleted.',
    });
  } catch (error) {
    console.error('Delete invoice error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to delete the invoice right now.',
    });
  }
}

async function markPaid(req, res) {
  try {
    const invoice = await invoiceRepository.findByIdForUser(
      req.params.id,
      req.userId,
    );
    if (!invoice) {
      return res.status(404).json({
        success: false,
        message: 'Invoice not found.',
      });
    }
    const updated = await invoiceRepository.markPaidAtomic(req.params.id, req.userId);
    return res.json({
      success: true,
      invoice: updated.toPublicJSON(),
    });
  } catch (error) {
    console.error('Mark paid error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to mark this invoice as paid.',
    });
  }
}

async function markPartial(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const invoice = await invoiceRepository.findByIdForUser(req.params.id, req.userId);
    if (!invoice) {
      return res.status(404).json({
        success: false,
        message: 'Invoice not found.',
      });
    }

    const amount = Number(req.body.amount);
    if (!Number.isFinite(amount) || amount <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Enter a payment amount greater than 0.',
      });
    }

    const updated = await invoiceRepository.addPartialPayment(req.params.id, req.userId, amount);
    if (updated?.overpayment) {
      return res.status(400).json({
        success: false,
        message: 'Payment cannot exceed the remaining balance.',
      });
    }
    return res.json({
      success: true,
      invoice: updated.toPublicJSON(),
    });
  } catch (error) {
    console.error('Mark partial error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to record that payment.',
    });
  }
}

async function extendDueDate(req, res) {
  if (sendValidationError(req, res)) return;

  try {
    const dueDate = parseDate(req.body.dueDate);
    if (!dueDate) {
      return res.status(400).json({
        success: false,
        message: 'Enter a valid due date.',
      });
    }

    const invoice = await invoiceRepository.updateInvoice(
      req.params.id,
      req.userId,
      { dueDate },
    );
    if (!invoice) {
      return res.status(404).json({
        success: false,
        message: 'Invoice not found.',
      });
    }
    return res.json({
      success: true,
      invoice: invoice.toPublicJSON(),
    });
  } catch (error) {
    console.error('Extend due date error:', error);
    return res.status(500).json({
      success: false,
      message: 'Unable to extend the due date.',
    });
  }
}

module.exports = {
  listInvoices,
  getInvoice,
  createInvoice,
  updateInvoice,
  deleteInvoice,
  markPaid,
  markPartial,
  extendDueDate,
};
