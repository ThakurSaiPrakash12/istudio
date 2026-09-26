const { randomUUID } = require('crypto');
const logger = require('../config/logger');

const SKIP_PREFIXES = ['/api/health', '/openapi.yaml', '/api-docs'];

function shouldSkip(req) {
  const path = req.originalUrl.split('?')[0];
  return SKIP_PREFIXES.some((prefix) => path === prefix || path.startsWith(`${prefix}/`));
}

function requestLogger(req, res, next) {
  const requestId = String(req.headers['x-request-id'] || randomUUID());
  req.requestId = requestId;
  res.setHeader('X-Request-Id', requestId);

  const skipAccessLog =
    (process.env.NODE_ENV === 'test' && process.env.LOG_REQUESTS !== 'true') ||
    shouldSkip(req);
  if (skipAccessLog) return next();

  const started = process.hrtime.bigint();
  res.on('finish', () => {
    const ms = Number(process.hrtime.bigint() - started) / 1e6;
    const payload = {
      requestId,
      method: req.method,
      path: req.originalUrl.split('?')[0],
      status: res.statusCode,
      ms: Math.round(ms),
    };
    if (req.userId) payload.userId = req.userId;

    if (res.statusCode >= 500) {
      logger.error('request failed', payload);
    } else if (res.statusCode >= 400) {
      logger.warn('request completed', payload);
    } else {
      logger.info('request completed', payload);
    }
  });

  return next();
}

module.exports = { requestLogger, shouldSkip };
