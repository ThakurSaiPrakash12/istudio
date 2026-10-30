'use strict';

const assert = require('node:assert/strict');
const { describe, it } = require('node:test');
const bcrypt = require('bcryptjs');
const { ensurePlayReviewAccount } = require('../src/services/playReviewAccountService');

describe('Google Play review account', () => {
  it('does nothing when review credentials are not configured', async () => {
    assert.equal(await ensurePlayReviewAccount({ email: '', password: '' }), null);
  });

  it('creates the account once and refreshes its password on later starts', async () => {
    let account = null;
    const repository = {
      async findByEmail(email) {
        assert.equal(email, 'test@gmail.com');
        return account;
      },
      async createUser(data) {
        account = { id: 'review-account-id', ...data };
        return account;
      },
      async updateUser(id, fields) {
        assert.equal(id, 'review-account-id');
        Object.assign(account, fields);
        return account;
      },
    };

    const firstStart = await ensurePlayReviewAccount({
      email: ' TEST@gmail.com ',
      password: '123456789',
      repository,
    });
    assert.deepEqual(firstStart, { created: true });
    assert.equal(account.email, 'test@gmail.com');
    assert.equal(await bcrypt.compare('123456789', account.password), true);

    const secondStart = await ensurePlayReviewAccount({
      email: 'test@gmail.com',
      password: '123456789',
      repository,
    });
    assert.deepEqual(secondStart, { created: false });
    assert.equal(await bcrypt.compare('123456789', account.password), true);
  });

  it('rejects incomplete or invalid credentials', async () => {
    await assert.rejects(
      ensurePlayReviewAccount({ email: 'test@gmail.com', password: '' }),
      /both email and password are required/,
    );
    await assert.rejects(
      ensurePlayReviewAccount({ email: 'test@gmail.com', password: 'short' }),
      /invalid/,
    );
  });
});