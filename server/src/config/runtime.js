const REQUIRED_PRODUCTION_VARS = [
  'MONGODB_URI',
  'JWT_SECRET',
  'CLOUDINARY_CLOUD_NAME',
  'CLOUDINARY_API_KEY',
  'CLOUDINARY_API_SECRET',
  'CORS_ORIGINS',
];

function validateProductionConfig(env = process.env) {
  if (env.NODE_ENV !== 'production') return;
  const missing = REQUIRED_PRODUCTION_VARS.filter((name) => !String(env[name] || '').trim());
  if (missing.length) throw new Error(`Missing production configuration: ${missing.join(', ')}`);
  if (env.JWT_SECRET.includes('replace_with') || env.JWT_SECRET.length < 32) {
    throw new Error('JWT_SECRET must be a strong production secret.');
  }
  if (env.CORS_ORIGINS.split(',').some((origin) => origin.trim() === '*')) {
    throw new Error('CORS_ORIGINS must not contain * in production.');
  }
}

function validateRuntimeConfig(env = process.env) {
  if (!env.JWT_SECRET || env.JWT_SECRET.includes('replace_with')) {
    throw new Error('Set JWT_SECRET before starting the API.');
  }
  validateProductionConfig(env);
}

function parseCorsOrigins(env = process.env) {
  const value = String(env.CORS_ORIGINS || 'http://localhost:5000');
  const origins = value.split(',').map((origin) => origin.trim()).filter(Boolean);
  for (const origin of origins) {
    let parsed;
    try {
      parsed = new URL(origin);
    } catch (_) {
      throw new Error(`Invalid CORS origin: ${origin}`);
    }
    if (!['http:', 'https:'].includes(parsed.protocol) || parsed.pathname !== '/' || parsed.search || parsed.hash) {
      throw new Error(`Invalid CORS origin: ${origin}`);
    }
  }
  return new Set(origins);
}

module.exports = { validateProductionConfig, validateRuntimeConfig, parseCorsOrigins };