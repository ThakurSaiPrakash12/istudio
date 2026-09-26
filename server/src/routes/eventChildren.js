const express = require('express');
const { body } = require('express-validator');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/businessController');
const { uploadPaymentProof, hasSupportedImageSignature } = require('../middleware/upload');
const { idempotency } = require('../middleware/idempotency');
const fs = require('fs');

const router = express.Router();
router.use(requireAuth);

const paymentRules = [
  body('title').trim().isLength({ min: 1, max: 160 }).withMessage('Enter a payment title.'),
  body('amount').isFloat({ gt: 0 }).withMessage('Enter a payment amount greater than zero.'),
  body('paidAt').isISO8601().withMessage('Enter a valid payment date.'),
  body('method').isIn(['cash', 'upi', 'bankTransfer', 'card', 'other']).withMessage('Enter a valid payment method.'),
  body('reference').optional().trim().isLength({ max: 160 }),
  body('proofUrl').optional().isURL({ protocols: ['https'], require_protocol: true }).withMessage('Payment proof must be an HTTPS URL.'),
];
const expenseRules = [
  body('title').trim().isLength({ min: 1, max: 160 }),
  body('amount').isFloat({ gt: 0 }),
  body('category').trim().isLength({ min: 1, max: 100 }),
  body('incurredAt').isISO8601(),
];
const deliverableRules = [
  body('title').trim().isLength({ min: 1, max: 200 }),
  body('stage').optional().trim().isLength({ max: 100 }),
  body('isCompleted').optional().isBoolean(),
];
const deliverableUpdateRules = [
  body('stage').optional().trim().isLength({ max: 100 }),
  body('title').optional().trim().isLength({ min: 1, max: 200 }),
  body('isCompleted').optional().isBoolean(),
];

router.get('/events/:eventId/payments', controller.listPayments);
router.post('/events/:eventId/payments', idempotency, paymentRules, controller.createPayment);
router.get('/payments/:id', controller.getPayment);
router.put('/payments/:id', [
  body('title').optional().trim().isLength({ min: 1, max: 160 }),
  body('amount').optional().isFloat({ gt: 0 }),
  body('paidAt').optional().isISO8601(),
  body('method').optional().isIn(['cash', 'upi', 'bankTransfer', 'card', 'other']),
  body('reference').optional().trim().isLength({ max: 160 }),
  body('proofUrl').optional().isURL({ protocols: ['https'], require_protocol: true }),
], controller.updatePayment);
router.delete('/payments/:id', controller.deletePayment);
router.post('/payments/:id/proof', controller.authorizePaymentProof, (req, res, next) => {
  uploadPaymentProof(req, res, (error) => {
    if (error) return res.status(400).json({ success: false, message: error.message || 'Invalid payment proof.' });
    if (!req.file || !hasSupportedImageSignature(req.file.path)) {
      if (req.file?.path && fs.existsSync(req.file.path)) fs.unlinkSync(req.file.path);
      return res.status(400).json({ success: false, message: 'Upload a valid JPG, PNG, GIF, WebP, or PDF proof.' });
    }
    return next();
  });
}, controller.uploadPaymentProof);

router.get('/events/:eventId/expenses', controller.listExpenses);
router.post('/events/:eventId/expenses', idempotency, expenseRules, controller.createExpense);
router.get('/expenses/:id', controller.getExpense);
router.put('/expenses/:id', [
  body('title').optional().trim().isLength({ min: 1, max: 160 }),
  body('amount').optional().isFloat({ gt: 0 }),
  body('category').optional().trim().isLength({ min: 1, max: 100 }),
  body('incurredAt').optional().isISO8601(),
], controller.updateExpense);
router.delete('/expenses/:id', controller.deleteExpense);

router.get('/events/:eventId/deliverables', controller.listDeliverables);
router.post('/events/:eventId/deliverables', idempotency, deliverableRules, controller.createDeliverable);
router.get('/deliverables/:id', controller.getDeliverable);
router.put('/deliverables/:id', deliverableUpdateRules, controller.updateDeliverable);
router.delete('/deliverables/:id', controller.deleteDeliverable);

module.exports = router;
