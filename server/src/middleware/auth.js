const jwt = require('jsonwebtoken');

function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const [scheme, token] = header.split(' ');

  if (scheme !== 'Bearer' || !token || header.split(' ').length !== 2) {
    return res.status(401).json({
      success: false,
      message: 'Please sign in to continue.',
    });
  }

  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET, {
      algorithms: ['HS256'],
    });
    if (!payload.id || typeof payload.id !== 'string') {
      throw new Error('Invalid token subject');
    }
    req.userId = payload.id;
    return next();
  } catch (_) {
    return res.status(401).json({
      success: false,
      message: 'Your session has expired. Please sign in again.',
    });
  }
}

module.exports = { requireAuth };
