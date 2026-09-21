const express = require('express');
const { body } = require('express-validator');
const { requireAuth } = require('../middleware/auth');
const controller = require('../controllers/businessController');

const router = express.Router();
router.use(requireAuth);

const rules = [
  body('name').trim().isLength({ min: 1, max: 160 }).withMessage('Enter a client name.'),
  body('phone').trim().isLength({ min: 3, max: 20 }).withMessage('Enter a valid phone number.'),
  body('email').optional({ checkFalsy: true }).trim().isEmail().isLength({ max: 160 }).withMessage('Enter a valid email address.'),
  body('address').optional().trim().isLength({ max: 300 }).withMessage('Address is too long.'),
  body('notes').optional().trim().isLength({ max: 1000 }).withMessage('Notes are too long.'),
];
const updateRules = [
  body('name').optional().trim().isLength({ min: 1, max: 160 }).withMessage('Enter a client name.'),
  body('phone').optional().trim().isLength({ min: 3, max: 20 }).withMessage('Enter a valid phone number.'),
  body('email').optional({ checkFalsy: true }).trim().isEmail().isLength({ max: 160 }).withMessage('Enter a valid email address.'),
  body('address').optional().trim().isLength({ max: 300 }).withMessage('Address is too long.'),
  body('notes').optional().trim().isLength({ max: 1000 }).withMessage('Notes are too long.'),
];

router.get('/', controller.listClients);
router.post('/', rules, controller.createClient);
router.get('/:id', controller.getClient);
router.put('/:id', updateRules, controller.updateClient);
router.delete('/:id', controller.deleteClient);

module.exports = router;
