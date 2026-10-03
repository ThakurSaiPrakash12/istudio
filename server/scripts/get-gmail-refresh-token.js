'use strict';

const http = require('node:http');
const dotenv = require('dotenv');
const { google } = require('googleapis');

dotenv.config();

const clientId = process.env.GOOGLE_CLIENT_ID;
const clientSecret = process.env.GOOGLE_CLIENT_SECRET;
const redirectUri = 'http://localhost:3000/oauth2callback';

if (!clientId || !clientSecret) {
  console.error('Set GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET before running this script.');
  process.exit(1);
}

const oauth2Client = new google.auth.OAuth2(clientId, clientSecret, redirectUri);
const authUrl = oauth2Client.generateAuthUrl({
  access_type: 'offline',
  prompt: 'consent',
  scope: ['https://www.googleapis.com/auth/gmail.send'],
});

console.log('\nOpen this URL in a browser and authorize the Gmail account used by the app:\n');
console.log(authUrl);
console.log(`\nWaiting for Google to redirect to ${redirectUri} ...\n`);

const server = http.createServer(async (request, response) => {
  try {
    const url = new URL(request.url, redirectUri);
    const code = url.searchParams.get('code');
    const error = url.searchParams.get('error');

    if (error) throw new Error(`Google authorization failed: ${error}`);
    if (!code) return;

    const { tokens } = await oauth2Client.getToken(code);
    response.end('Authorization complete. You can close this window.');
    console.log('\nAdd this Render environment variable:\n');
    console.log(`GMAIL_REFRESH_TOKEN=${tokens.refresh_token || '(no refresh token returned)'}`);
    console.log('\nKeep the refresh token secret.\n');
    server.close();
  } catch (err) {
    response.statusCode = 500;
    response.end('Authorization failed. Check the terminal for details.');
    console.error(err.message);
    server.close();
    process.exitCode = 1;
  }
});

server.listen(3000, '127.0.0.1');
