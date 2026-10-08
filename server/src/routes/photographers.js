const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { searchNearbyPhotographers } = require('../controllers/photographerController');

const router = express.Router();
router.use(requireAuth);

router.get('/nearby', searchNearbyPhotographers);
router.get('/search', searchNearbyPhotographers);
router.get('/', searchNearbyPhotographers);

module.exports = router;
