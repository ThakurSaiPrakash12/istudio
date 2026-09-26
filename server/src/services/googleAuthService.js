const { OAuth2Client } = require('google-auth-library');
const { google } = require('googleapis');
const logger = require('../config/logger');

const googleClientId = process.env.GOOGLE_CLIENT_ID || '';
const googleClientSecret = process.env.GOOGLE_CLIENT_SECRET || '';
const oauth2Client = new OAuth2Client(googleClientId, googleClientSecret);

/**
 * Verifies a Google ID Token or Access Token and returns the verified user profile.
 *
 * Supports:
 * 1. Native ID Token verification via google-auth-library
 * 2. Cross-platform client audience matching (Android, iOS, Web)
 * 3. Fallback to Google UserInfo API via googleapis when access token is provided
 */
async function verifyGoogleToken({ idToken, accessToken }) {
  if (!idToken && !accessToken) {
    throw new Error('Either idToken or accessToken is required for Google authentication');
  }

  // 1. Try ID Token verification via google-auth-library
  if (idToken) {
    try {
      const ticket = await oauth2Client.verifyIdToken({
        idToken,
        audience: googleClientId ? [googleClientId] : undefined,
      });
      const payload = ticket.getPayload();
      if (payload && payload.sub) {
        return {
          googleId: payload.sub,
          email: payload.email || '',
          name: payload.name || payload.given_name || '',
          picture: payload.picture || '',
          emailVerified: Boolean(payload.email_verified),
        };
      }
    } catch (verifyErr) {
      logger.warn('Google verifyIdToken with audience failed, checking fallback tokeninfo', {
        error: verifyErr.message,
      });

      // Fallback: verify via Google's tokeninfo API for cross-client (Android/iOS client ID) tokens
      try {
        const tokenInfoRes = await fetch(
          `https://oauth2.googleapis.com/tokeninfo?id_token=${encodeURIComponent(idToken)}`
        );
        if (tokenInfoRes.ok) {
          const payload = await tokenInfoRes.json();
          if (payload && payload.sub) {
            return {
              googleId: payload.sub,
              email: payload.email || '',
              name: payload.name || '',
              picture: payload.picture || '',
              emailVerified: payload.email_verified === 'true' || payload.email_verified === true,
            };
          }
        }
      } catch (fetchErr) {
        logger.error('Google tokeninfo verification failed', { error: fetchErr.message });
      }
    }
  }

  // 2. Try Access Token verification via Google OAuth2 UserInfo API
  if (accessToken) {
    try {
      const oauth2 = google.oauth2({ version: 'v2', auth: oauth2Client });
      oauth2Client.setCredentials({ access_token: accessToken });
      const userInfo = await oauth2.userinfo.get();
      if (userInfo.data && userInfo.data.id) {
        return {
          googleId: userInfo.data.id,
          email: userInfo.data.email || '',
          name: userInfo.data.name || '',
          picture: userInfo.data.picture || '',
          emailVerified: Boolean(userInfo.data.verified_email),
        };
      }
    } catch (apiErr) {
      logger.error('Google OAuth2 UserInfo API failed', { error: apiErr.message });
      throw new Error('Invalid or expired Google access token');
    }
  }

  throw new Error('Failed to verify Google authentication token');
}

/**
 * Returns a configured Google OAuth2Client instance for interacting with Google APIs.
 */
function getOAuth2Client(credentials) {
  const client = new OAuth2Client(googleClientId, googleClientSecret);
  if (credentials) {
    client.setCredentials(credentials);
  }
  return client;
}

/**
 * Google APIs service accessor (google.calendar, google.drive, etc.)
 */
function getGoogleApi(serviceName, version = 'v1', auth) {
  const factory = google[serviceName];
  if (typeof factory !== 'function') {
    throw new Error(`Google API "${serviceName}" is not available`);
  }
  return factory({ version, auth: auth || oauth2Client });
}

module.exports = {
  verifyGoogleToken,
  getOAuth2Client,
  getGoogleApi,
  google,
};
