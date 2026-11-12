const https = require('https');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const logger = require('../config/logger');

const APPLE_ISSUER = 'https://appleid.apple.com';
const EXPECTED_BUNDLE_ID = process.env.APPLE_BUNDLE_ID || 'com.lumen.lumenStudio';
const APPLE_JWKS_URL = 'https://appleid.apple.com/auth/keys';

// In-memory cache for Apple public keys (JWKS)
let cachedAppleKeys = null;
let keysCachedAt = 0;
const CACHE_TTL_MS = 24 * 60 * 60 * 1000; // 24 hours

/**
 * Fetches Apple's public JWK set from https://appleid.apple.com/auth/keys
 */
function fetchAppleJwks() {
  return new Promise((resolve, reject) => {
    https.get(APPLE_JWKS_URL, (res) => {
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return reject(new Error(`Apple JWKS request failed with status ${res.statusCode}`));
      }
      let rawData = '';
      res.on('data', (chunk) => {
        rawData += chunk;
      });
      res.on('end', () => {
        try {
          const parsed = JSON.parse(rawData);
          if (!Array.isArray(parsed.keys)) {
            return reject(new Error('Invalid Apple JWKS response format.'));
          }
          resolve(parsed.keys);
        } catch (err) {
          reject(err);
        }
      });
    }).on('error', (err) => {
      reject(err);
    });
  });
}

/**
 * Returns cached Apple keys or fetches them fresh.
 */
async function getApplePublicKeys(forceRefresh = false) {
  const now = Date.now();
  if (!forceRefresh && cachedAppleKeys && (now - keysCachedAt < CACHE_TTL_MS)) {
    return cachedAppleKeys;
  }
  try {
    const keys = await fetchAppleJwks();
    cachedAppleKeys = keys;
    keysCachedAt = now;
    return keys;
  } catch (err) {
    if (cachedAppleKeys) {
      logger.warn('Failed to refresh Apple JWKS, using cached keys', { error: err.message });
      return cachedAppleKeys;
    }
    throw err;
  }
}

/**
 * Verifies an Apple identity token cryptographically using Apple's JWKS.
 * Checks:
 * - Signature matching Apple's RS256 public key (by `kid`)
 * - Token expiration (`exp`)
 * - Issuer `iss === https://appleid.apple.com`
 * - Audience `aud === com.lumen.lumenStudio`
 *
 * @param {Object} params
 * @param {string} [params.identityToken]
 * @param {string} [params.userIdentifier]
 * @param {string} [params.email]
 * @param {Object|string} [params.fullName]
 * @param {string} [params.nonce]
 */
async function verifyAppleToken({ identityToken, userIdentifier, email, fullName, nonce }) {
  if (!identityToken && !userIdentifier) {
    throw new Error('Apple identity token or user identifier is required.');
  }

  let verifiedPayload = null;

  if (identityToken) {
    // In test environment, allow mock tokens for supertest / unit tests
    if (process.env.NODE_ENV === 'test' && identityToken.startsWith('mock_')) {
      verifiedPayload = {
        sub: userIdentifier || 'test-apple-sub',
        email: email || 'test@privaterelay.appleid.com',
        iss: APPLE_ISSUER,
        aud: EXPECTED_BUNDLE_ID,
      };
    } else {
      const decodedHeader = jwt.decode(identityToken, { complete: true });
      if (!decodedHeader || !decodedHeader.header) {
        throw new Error('Invalid Apple identity token structure.');
      }

      const { kid, alg } = decodedHeader.header;
      if (alg !== 'RS256') {
        throw new Error(`Unsupported Apple token algorithm: ${alg}`);
      }

      let keys = await getApplePublicKeys();
      let matchingKey = keys.find((k) => k.kid === kid);

      // If not found in cache, attempt one fresh fetch in case Apple rotated keys
      if (!matchingKey) {
        keys = await getApplePublicKeys(true);
        matchingKey = keys.find((k) => k.kid === kid);
      }

      if (!matchingKey) {
        throw new Error(`Unable to find matching Apple public key for kid: ${kid}`);
      }

      // Convert JWK to PEM public key using Node's crypto
      const publicKey = crypto.createPublicKey({
        key: {
          kty: matchingKey.kty,
          n: matchingKey.n,
          e: matchingKey.e,
        },
        format: 'jwk',
      });

      // Cryptographically verify signature, issuer, and audience
      verifiedPayload = jwt.verify(identityToken, publicKey, {
        algorithms: ['RS256'],
        issuer: APPLE_ISSUER,
        audience: EXPECTED_BUNDLE_ID,
      });

      if (nonce && verifiedPayload.nonce && verifiedPayload.nonce !== nonce) {
        throw new Error('Apple token nonce mismatch.');
      }
    }
  }

  const appleId = (verifiedPayload && verifiedPayload.sub) || userIdentifier;
  if (!appleId) {
    throw new Error('Could not extract Apple user identifier.');
  }

  const tokenEmail = (verifiedPayload && verifiedPayload.email) || email || '';

  let name = '';
  if (fullName) {
    if (typeof fullName === 'string') {
      name = fullName.trim();
    } else if (typeof fullName === 'object') {
      name = [fullName.givenName, fullName.familyName].filter(Boolean).join(' ').trim();
    }
  }

  return {
    appleId,
    email: tokenEmail,
    name,
    isPrivateEmail: tokenEmail.endsWith('@privaterelay.appleid.com'),
  };
}

/**
 * Revokes Apple token via Apple's REST endpoint (guideline 5.1.1(v) compliance)
 * Requires Apple private key and client secret configuration.
 */
async function revokeAppleToken({ token, tokenTypeHint = 'refresh_token' }) {
  if (!token) return false;
  try {
    const clientSecret = process.env.APPLE_CLIENT_SECRET;
    if (!clientSecret) {
      logger.info('Apple client secret not configured; skipping remote token revocation');
      return false;
    }

    const postData = new URLSearchParams({
      client_id: EXPECTED_BUNDLE_ID,
      client_secret: clientSecret,
      token,
      token_type_hint: tokenTypeHint,
    }).toString();

    return new Promise((resolve) => {
      const req = https.request(
        'https://appleid.apple.com/auth/revoke',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Content-Length': Buffer.byteLength(postData),
          },
        },
        (res) => {
          resolve(res.statusCode === 200);
        },
      );
      req.on('error', (err) => {
        logger.warn('Failed to call Apple token revocation endpoint', { error: err.message });
        resolve(false);
      });
      req.write(postData);
      req.end();
    });
  } catch (err) {
    logger.warn('Error during Apple token revocation', { error: err.message });
    return false;
  }
}

// Allow injecting mock keys in tests
function setMockAppleKeys(keys) {
  cachedAppleKeys = keys;
  keysCachedAt = Date.now();
}

module.exports = {
  verifyAppleToken,
  revokeAppleToken,
  getApplePublicKeys,
  setMockAppleKeys,
};
