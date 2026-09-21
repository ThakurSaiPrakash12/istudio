const express = require('express');
const { body } = require('express-validator');

const { requireAuth } = require('../middleware/auth');
const {
  listInvoices,
  getInvoice,
  createInvoice,
  updateInvoice,
  deleteInvoice,
  markPaid,
  markPartial,
  extendDueDate,
} = require('../controllers/invoiceController');
const { normalizePhone } = require('../controllers/authController');
const { idempotency } = require('../middleware/idempotency');

const router = express.Router();

router.use(requireAuth);

const createRules = [
  body('eventName')
    .trim()
    .isLength({ min: 1, max: 160 })
    .withMessage('Enter an event name up to 160 characters'),
  body('contactName')
    .trim()
    .isLength({ min: 1, max: 120 })
    .withMessage('Enter the contact person name up to 120 characters'),
  body('phone')
    .customSanitizer(normalizePhone)
    .isLength({ min: 10, max: 10 })
    .withMessage('Enter a valid 10-digit phone number'),
  body('address')
    .trim()
    .isLength({ min: 1, max: 300 })
    .withMessage('Enter a billing address up to 300 characters'),
  body('dueDate').isISO8601().withMessage('Choose a valid due date'),
  body('issuedOn').optional().isISO8601().withMessage('Enter a valid issue date'),
  body('amountReceived')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Amount received cannot be negative'),
  body('deliverables')
    .isArray({ min: 1 })
    .withMessage('Add at least one deliverable'),
  body('deliverables.*.name')
    .trim()
    .isLength({ min: 1, max: 160 })
    .withMessage('Each deliverable needs a name up to 160 characters'),
  body('deliverables.*.cost')
    .isFloat({ gt: 0 })
    .withMessage('Each deliverable needs a cost greater than 0'),
];

const updateRules = [
  body('eventName').optional().trim().isLength({ min: 1, max: 160 }),
  body('contactName').optional().trim().isLength({ min: 1, max: 120 }),
  body('phone')
    .optional()
    .customSanitizer(normalizePhone)
    .isLength({ min: 10, max: 10 })
    .isNumeric()
    .withMessage('Enter a valid 10-digit phone number'),
  body('address').optional().trim().isLength({ min: 1, max: 300 }),
  body('upiId').optional().trim().isLength({ max: 120 }),
  body('issuedOn').optional().isISO8601().withMessage('Enter a valid issue date'),
  body('dueDate').optional().isISO8601().withMessage('Enter a valid due date'),
  body('amountReceived')
    .optional()
    .isFloat({ min: 0 })
    .withMessage('Amount received cannot be negative'),
  body('deliverables').optional().isArray({ min: 1 }),
  body('deliverables.*.name').optional().trim().isLength({ min: 1, max: 160 }),
  body('deliverables.*.cost').optional().isFloat({ gt: 0 }),
];

router.get('/', listInvoices);
router.post('/', idempotency, createRules, createInvoice);
router.get('/:id', getInvoice);
router.patch('/:id', updateRules, updateInvoice);
router.delete('/:id', deleteInvoice);
router.post('/:id/paid', idempotency, markPaid);
router.post(
  '/:id/partial',
  idempotency,
  [body('amount').isFloat({ gt: 0 }).withMessage('Enter a payment amount greater than 0')],
  markPartial,
);
router.patch(
  '/:id/due-date',
  [body('dueDate').isISO8601().withMessage('Enter a valid due date')],
  extendDueDate,
);

module.exports = router;
