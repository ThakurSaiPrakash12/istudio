const userRepository = require('../repositories/userRepository');
const logger = require('../config/logger');

function calculateDistanceKm(lat1, lon1, lat2, lon2) {
  if (
    lat1 === null || lat1 === undefined ||
    lon1 === null || lon1 === undefined ||
    lat2 === null || lat2 === undefined ||
    lon2 === null || lon2 === undefined
  ) {
    return null;
  }
  const nLat1 = Number(lat1);
  const nLon1 = Number(lon1);
  const nLat2 = Number(lat2);
  const nLon2 = Number(lon2);
  if (isNaN(nLat1) || isNaN(nLon1) || isNaN(nLat2) || isNaN(nLon2)) return null;

  const R = 6371; // Earth's mean radius in km
  const dLat = (nLat2 - nLat1) * (Math.PI / 180);
  const dLon = (nLon2 - nLon1) * (Math.PI / 180);
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(nLat1 * (Math.PI / 180)) *
      Math.cos(nLat2 * (Math.PI / 180)) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c * 10) / 10;
}

async function searchNearbyPhotographers(req, res) {
  try {
    const location = String(req.query.location || req.query.city || '').trim();
    const query = String(req.query.query || '').trim();
    const category = String(req.query.category || '').trim();
    const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 100);

    let originLat = req.query.lat !== undefined ? req.query.lat : req.query.latitude;
    let originLng = req.query.lng !== undefined ? req.query.lng : req.query.longitude;

    const hasOriginCoords =
      originLat !== undefined && originLng !== undefined &&
      originLat !== '' && originLng !== '' &&
      !isNaN(Number(originLat)) && !isNaN(Number(originLng));

    const users = await userRepository.searchPhotographers({
      userId: req.userId,
      location,
      query,
      category,
      limit,
    });

    let photographers = (users || []).map((u) => {
      const json = u.toPublicJSON ? u.toPublicJSON() : u;
      const pLat = json.latitude;
      const pLng = json.longitude;

      let distanceKm = null;
      if (
        hasOriginCoords &&
        pLat !== null && pLat !== undefined &&
        pLng !== null && pLng !== undefined &&
        !isNaN(Number(pLat)) && !isNaN(Number(pLng))
      ) {
        distanceKm = calculateDistanceKm(originLat, originLng, pLat, pLng);
      }
      return {
        ...json,
        latitude: pLat !== undefined ? pLat : null,
        longitude: pLng !== undefined ? pLng : null,
        distanceKm,
      };
    });

    if (hasOriginCoords) {
      photographers.sort((a, b) => {
        if (a.distanceKm != null && b.distanceKm != null) {
          return a.distanceKm - b.distanceKm;
        }
        if (a.distanceKm != null) return -1;
        if (b.distanceKm != null) return 1;
        return 0;
      });
    }

    return res.json({
      success: true,
      photographers,
      total: photographers.length,
    });
  } catch (error) {
    logger.error('searchNearbyPhotographers error', logger.fromRequest(req, error));
    return res.status(500).json({
      success: false,
      message: 'Unable to search photographers at this time.',
    });
  }
}

module.exports = {
  calculateDistanceKm,
  searchNearbyPhotographers,
};
