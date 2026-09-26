const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.join(__dirname, '..', '.env') });

const express = require('express');
const swaggerUi = require('swagger-ui-express');
const cors = require('cors');
const helmet = require('helmet');
const { rateLimit } = require('express-rate-limit');
const { validateRuntimeConfig, parseCorsOrigins } = require('./config/runtime');
const { checkCloudinaryReadiness } = require('./config/cloudinary');
const logger = require('./config/logger');
const { requestLogger } = require('./middleware/requestLogger');

const { connectDb } = require('./config/db');
const authRoutes = require('./routes/auth');
const invoiceRoutes = require('./routes/invoices');
const clientRoutes = require('./routes/clients');
const eventRoutes = require('./routes/events');
const eventChildRoutes = require('./routes/eventChildren');

const app = express();
app.set('trust proxy', 1);
const openApiPath = path.join(__dirname, '..', '..', 'openapi.yaml');
validateRuntimeConfig();
const port = Number(process.env.PORT) || 5000;
const allowedOrigins = parseCorsOrigins();
const authRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  message: {
    success: false,
    message: 'Too many authentication attempts. Please try again later.',
  },
});

app.use(helmet());
app.use(requestLogger);
app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.has(origin)) return callback(null, true);
    return callback(new Error('Origin is not allowed.'));
  },
}));
app.use(express.json({ limit: '6mb' }));

app.get('/openapi.yaml', (_req, res) => {
  res.type('yaml').sendFile(openApiPath);
});
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(null, {
  swaggerOptions: { url: '/openapi.yaml' },
  customSiteTitle: 'Lumen Studio API Docs',
}));

app.get('/', (_req, res) => {
  res.json({
    success: true,
    service: 'lumen-studio-api',
    message: 'Lumen Studio API is running.',
    routes: {
      health: 'GET /api/health',
      signup: 'POST /api/auth/signup',
      login: 'POST /api/auth/login',
      me: 'GET /api/auth/me',
      profile: 'PATCH /api/auth/profile',
      logo: 'POST /api/auth/logo',
      invoices: 'GET /api/invoices',
      createInvoice: 'POST /api/invoices',
      invoice: 'GET /api/invoices/:id',
      updateInvoice: 'PATCH /api/invoices/:id',
      deleteInvoice: 'DELETE /api/invoices/:id',
      markPaid: 'POST /api/invoices/:id/paid',
      markPartial: 'POST /api/invoices/:id/partial',
      extendDueDate: 'PATCH /api/invoices/:id/due-date',
      clients: 'GET /api/clients',
      events: 'GET /api/events',
      payments: 'GET /api/events/:eventId/payments',
      expenses: 'GET /api/events/:eventId/expenses',
      deliverables: 'GET /api/events/:eventId/deliverables',
    },
  });
});

app.get('/api/health', (_req, res) => {
  res.json({ success: true, service: 'lumen-studio-api' });
});
app.get('/api/health/live', (_req, res) => {
  res.json({ success: true, status: 'live' });
});
app.get('/api/health/ready', async (_req, res) => {
  const mongoReady = require('mongoose').connection.readyState === 1;
  const cloudinary = await checkCloudinaryReadiness({ ping: process.env.NODE_ENV === 'production' });
  const ready = mongoReady && cloudinary.configured && cloudinary.reachable;
  return res.status(ready ? 200 : 503).json({
    success: ready,
    status: ready ? 'ready' : 'not_ready',
    dependencies: { mongodb: mongoReady, cloudinary },
  });
});

app.use('/api/auth', authRateLimit, authRoutes);
app.use('/api/invoices', invoiceRoutes);
app.use('/api/clients', clientRoutes);
app.use('/api/events', eventRoutes);
app.use('/api', eventChildRoutes);

app.use((error, req, res, _next) => {
  if (error.message === 'Origin is not allowed.') {
    logger.warn('CORS origin rejected', { requestId: req.requestId, origin: req.headers.origin });
    return res.status(403).json({ success: false, message: 'Origin is not allowed.' });
  }
  logger.error('Unhandled request error', logger.fromRequest(req, error));
  return res.status(500).json({ success: false, message: 'Unable to process the request.' });
});

app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `No route for ${req.method} ${req.originalUrl}`,
  });
});

async function start() {
  process.on('unhandledRejection', (reason) => {
    logger.error('Unhandled promise rejection', reason instanceof Error ? reason : { error: reason });
  });
  process.on('uncaughtException', (error) => {
    logger.error('Uncaught exception', error);
    process.exit(1);
  });

  try {
    validateRuntimeConfig();
    await connectDb();
    app.listen(port, '0.0.0.0', () => {
      logger.info('API listening', {
        port,
        env: process.env.NODE_ENV || 'development',
        logLevel: logger.level,
      });
    });
  } catch (error) {
    logger.error('Failed to start API', error);
    process.exit(1);
  }
}

if (require.main === module) {
  start();
}

module.exports = { app, start };
