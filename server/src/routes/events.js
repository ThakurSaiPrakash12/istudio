const express = require('express');
const { body } = require('express-validator');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/businessController');
const { idempotency } = require('../middleware/idempotency');

const router = express.Router();
router.use(requireAuth);

const createRules = [
  body('title').trim().isLength({ min: 1, max: 200 }).withMessage('Enter an event title.'),
  body('eventType').trim().isLength({ min: 1, max: 80 }).withMessage('Enter an event type.'),
  body('startsAt').isISO8601().withMessage('Enter a valid event date.'),
  body('startTime').optional().trim().isLength({ max: 30 }),
  body('endTime').optional().trim().isLength({ max: 30 }),
  body('location').trim().isLength({ min: 1, max: 240 }).withMessage('Enter an event location.'),
  body('status').isIn(['upcoming', 'inProgress', 'paymentDue', 'completed', 'cancelled']).withMessage('Enter a valid event status.'),
  body('totalAmount').isFloat({ min: 0 }).withMessage('Enter a valid event amount.'),
  body('clientId').optional().isMongoId().withMessage('Enter a valid client.'),
  body('notes').optional().trim().isLength({ max: 2000 }),
];
const updateRules = [
  body('title').optional().trim().isLength({ min: 1, max: 200 }),
  body('eventType').optional().trim().isLength({ min: 1, max: 80 }),
  body('startsAt').optional().isISO8601(),
  body('startTime').optional().trim().isLength({ max: 30 }),
  body('endTime').optional().trim().isLength({ max: 30 }),
  body('location').optional().trim().isLength({ min: 1, max: 240 }),
  body('status').optional().isIn(['upcoming', 'inProgress', 'paymentDue', 'completed', 'cancelled']),
  body('totalAmount').optional().isFloat({ min: 0 }),
  body('clientId').optional().isMongoId(),
  body('notes').optional().trim().isLength({ max: 2000 }),
];

router.get('/', controller.listEvents);
router.post('/', idempotency, createRules, controller.createEvent);
router.get('/:id', controller.getEvent);
router.put('/:id', updateRules, controller.updateEvent);
router.delete('/:id', controller.deleteEvent);

module.exports = router;
