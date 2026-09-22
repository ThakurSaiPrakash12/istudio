const assert = require('assert');
const request = require('supertest');

process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'docs-test-secret-with-enough-length';
process.env.CLOUDINARY_TEST_MODE = 'true';

const { app } = require('../src/server');

async function run() {
  const spec = await request(app).get('/openapi.yaml');
  assert.strictEqual(spec.status, 200);
  assert.match(spec.type, /yaml/);
  assert.match(spec.text, /openapi:\s*3\.0\.3/);
  assert.match(spec.text, /\/clients:/);

  const docs = await request(app).get('/api-docs/');
  assert.strictEqual(docs.status, 200);
  assert.match(docs.text, /swagger-ui/);

  const config = await request(app).get('/api-docs/swagger-ui-init.js');
  assert.strictEqual(config.status, 200);
  assert.match(config.text, /\/openapi\.yaml/);
}

run().then(() => {
  console.log('Documentation endpoint tests passed.');
}).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});