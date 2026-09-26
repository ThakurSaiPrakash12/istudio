const assert = require('assert');
const { createLogger, redact, levelFromEnv, maskPhone } = require('../src/config/logger');
const { shouldSkip } = require('../src/middleware/requestLogger');

assert.strictEqual(redact('secret', 'password'), '[redacted]');
assert.strictEqual(redact({ password: 'hunter2', phone: '9876543210' }).password, '[redacted]');
assert.strictEqual(redact({ password: 'hunter2', phone: '9876543210' }).phone, '9876543210');
assert.strictEqual(redact({ authorization: 'Bearer abc' }).authorization, '[redacted]');
assert.strictEqual(redact({ otp: '123456' }).otp, '[redacted]');
assert.strictEqual(redact({ debugOtp: '999111' }).debugOtp, '[redacted]');
assert.strictEqual(redact({ MONGODB_URI: 'mongodb://user:pass@host/db' }).MONGODB_URI, '[redacted]');
assert.strictEqual(maskPhone('9876543210'), '98****10');

const prodLines = [];
const prodLogger = createLogger({
  env: { NODE_ENV: 'production' },
  stream: { write: (line) => prodLines.push(line) },
});
prodLogger.info('listening', { port: 5000 });
assert.strictEqual(JSON.parse(prodLines[0]).msg, 'listening');

assert.strictEqual(levelFromEnv({ NODE_ENV: 'test' }), 'error');
assert.strictEqual(levelFromEnv({ NODE_ENV: 'production' }), 'info');
assert.strictEqual(levelFromEnv({ LOG_LEVEL: 'debug' }), 'debug');

const lines = [];
const logger = createLogger({
  env: { LOG_LEVEL: 'info', LOG_FORMAT: 'json', NODE_ENV: 'test' },
  stream: { write: (line) => lines.push(line) },
});
logger.info('user signed in', { password: 'nope', userId: 'u1' });
logger.debug('should not appear', { ok: true });
assert.strictEqual(lines.length, 1);
const parsed = JSON.parse(lines[0]);
assert.strictEqual(parsed.msg, 'user signed in');
assert.strictEqual(parsed.password, '[redacted]');
assert.strictEqual(parsed.userId, 'u1');
assert.ok(!parsed.debug);

logger.error('boom', new Error('db down'));
const errorLine = JSON.parse(lines[1]);
assert.strictEqual(errorLine.error.message, 'db down');
assert.ok(errorLine.error.stack);

assert.strictEqual(shouldSkip({ originalUrl: '/api/health' }), true);
assert.strictEqual(shouldSkip({ originalUrl: '/api/health/ready' }), true);
assert.strictEqual(shouldSkip({ originalUrl: '/api/health?check=1' }), true);
assert.strictEqual(shouldSkip({ originalUrl: '/api/auth/login' }), false);

console.log('logger checks passed');
