const nodemailer = require('nodemailer');
const dns = require('node:dns');
const { google } = require('googleapis');
const { OAuth2Client } = require('google-auth-library');
const logger = require('../config/logger');

dns.setDefaultResultOrder('ipv4first');

let transporter = null;

const HTTP_SEND_TIMEOUT_MS = 15000;

function gmailApiConfigured() {
  return Boolean(
    String(process.env.GOOGLE_CLIENT_ID || '').trim() &&
      String(process.env.GOOGLE_CLIENT_SECRET || '').trim() &&
      String(process.env.GMAIL_REFRESH_TOKEN || '').trim() &&
      String(process.env.GMAIL_USER || '').trim(),
  );
}

function configuredFromAddress() {
  const configured = String(
    process.env.EMAIL_FROM ||
      'Clients Hub Studio <no-reply@clientshub.com>',
  ).trim();

  // Render values are sometimes pasted with one extra pair of quotes.
  const unwrapped = configured.replace(/^("|')(.*)\1$/, '$2').trim();
  const displayName = unwrapped.match(/^(?:"([^"]+)"|([^<]+))\s*<([^<>]+)>$/);
  if (!displayName) return unwrapped;

  const name = (displayName[1] || displayName[2]).trim();
  const email = displayName[3].trim();
  return `${name} <${email}>`;
}

function encodeMimeMessage({ from, to, replyTo, subject, text, html }) {
  const boundary = `=_ClientsHub_${Date.now()}_${Math.random().toString(16).slice(2)}`;
  const headers = [
    `From: ${from}`,
    `To: ${to}`,
    ...(replyTo ? [`Reply-To: ${replyTo}`] : []),
    `Subject: ${subject}`,
    'MIME-Version: 1.0',
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
  ];
  const mime = [
    ...headers,
    '',
    `--${boundary}`,
    'Content-Type: text/plain; charset="UTF-8"',
    'Content-Transfer-Encoding: 8bit',
    '',
    text,
    `--${boundary}`,
    'Content-Type: text/html; charset="UTF-8"',
    'Content-Transfer-Encoding: 8bit',
    '',
    html,
    `--${boundary}--`,
    '',
  ].join('\r\n');

  return Buffer.from(mime, 'utf8')
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}

async function sendWithGmailApi({ from, to, replyTo, subject, text, html }) {
  const oauth2Client = new OAuth2Client(
    process.env.GOOGLE_CLIENT_ID,
    process.env.GOOGLE_CLIENT_SECRET,
  );
  oauth2Client.setCredentials({
    refresh_token: process.env.GMAIL_REFRESH_TOKEN,
  });

  const gmail = google.gmail({ version: 'v1', auth: oauth2Client });
  const response = await gmail.users.messages.send({
    userId: 'me',
    requestBody: {
      raw: encodeMimeMessage({ from, to, replyTo, subject, text, html: html || '' }),
    },
  });

  return { sent: true, messageId: response.data.id };
}

function getTransporter() {
  if (transporter) return transporter;

  const host = process.env.SMTP_HOST;
  const user = process.env.SMTP_USER || process.env.GMAIL_USER;
  const pass = process.env.SMTP_PASS || process.env.GMAIL_APP_PASSWORD;

  const smtpTimeoutOpts = {
    connectionTimeout: 10000,  // 10s to establish TCP connection
    socketTimeout: 15000,      // 15s of inactivity on socket
    greetingTimeout: 10000,    // 10s to wait for server greeting
  };

  if (host && user && pass) {
    transporter = nodemailer.createTransport({
      host,
      port: Number(process.env.SMTP_PORT) || 587,
      secure: process.env.SMTP_SECURE === 'true' || process.env.SMTP_PORT === '465',
      auth: { user, pass },
      ...smtpTimeoutOpts,
    });
  } else if (process.env.GMAIL_USER && process.env.GMAIL_APP_PASSWORD) {
    transporter = nodemailer.createTransport({
      service: 'gmail',
      auth: {
        user: process.env.GMAIL_USER,
        pass: process.env.GMAIL_APP_PASSWORD,
      },
      ...smtpTimeoutOpts,
    });
  }

  return transporter;
}

function renderOtpEmailHtml({ otp, username }) {
  const brandName = 'CLIENTS HUB';
  const subTitle = 'STUDIO OS';

  return `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Your Verification Code - ${brandName}</title>
  <style>
    body {
      margin: 0;
      padding: 0;
      background-color: #0b0f17;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      color: #e2e8f0;
    }
    .wrapper {
      max-width: 560px;
      margin: 40px auto;
      padding: 32px 24px;
      background: #111827;
      border: 1px solid #1e293b;
      border-radius: 20px;
      box-shadow: 0 10px 30px rgba(0, 0, 0, 0.4);
    }
    .header {
      text-align: center;
      margin-bottom: 28px;
    }
    .brand-title {
      font-size: 24px;
      font-weight: 800;
      letter-spacing: 3px;
      color: #ffffff;
      margin: 0;
    }
    .brand-tag {
      display: inline-block;
      margin-top: 6px;
      font-size: 10px;
      font-weight: 700;
      letter-spacing: 2px;
      color: #60a5fa;
      background: rgba(96, 165, 250, 0.15);
      border: 1px solid rgba(96, 165, 250, 0.3);
      padding: 3px 10px;
      border-radius: 999px;
    }
    .greeting {
      font-size: 16px;
      color: #94a3b8;
      margin-bottom: 12px;
    }
    .message {
      font-size: 15px;
      line-height: 1.6;
      color: #cbd5e1;
      margin-bottom: 24px;
    }
    .otp-card {
      background: #1e293b;
      border: 1px solid #334155;
      border-radius: 14px;
      padding: 24px;
      text-align: center;
      margin: 28px 0;
    }
    .otp-code {
      font-size: 36px;
      font-weight: 800;
      letter-spacing: 8px;
      color: #38bdf8;
      font-family: monospace;
      margin: 0;
    }
    .otp-expiry {
      font-size: 12px;
      color: #94a3b8;
      margin-top: 10px;
    }
    .footer {
      border-top: 1px solid #1e293b;
      padding-top: 20px;
      margin-top: 32px;
      font-size: 12px;
      color: #64748b;
      text-align: center;
      line-height: 1.5;
    }
  </style>
</head>
<body>
  <div class="wrapper">
    <div class="header">
      <h1 class="brand-title">${brandName}</h1>
      <span class="brand-tag">${subTitle}</span>
    </div>

    <p class="greeting">Hello${username ? ` <strong>${username}</strong>` : ''},</p>
    <p class="message">
      Thank you for joining <strong>${brandName}</strong>. Please use the following 6-digit verification code to verify your email address and complete your account setup:
    </p>

    <div class="otp-card">
      <div class="otp-code">${otp}</div>
      <div class="otp-expiry">Valid for 10 minutes • Do not share this code with anyone.</div>
    </div>

    <p class="message" style="font-size: 13px; color: #94a3b8;">
      If you did not request this verification code, you can safely ignore this email.
    </p>

    <div class="footer">
      © ${new Date().getFullYear()} ${brandName} (${subTitle}). All rights reserved.
    </div>
  </div>
</body>
</html>
  `;
}

async function sendVerificationEmail({ to, otp, username = '' }) {
  const subject = `Your Verification Code: ${otp} - Clients Hub`;
  const from = configuredFromAddress();
  const text = `Hello${username ? ' ' + username : ''},\n\nYour Clients Hub verification code is: ${otp}\nThis code is valid for 10 minutes.\n\nIf you did not request this, please ignore this email.`;
  const html = renderOtpEmailHtml({ otp, username });

  try {
    if (gmailApiConfigured()) {
      const result = await sendWithGmailApi({ from, to, subject, text, html });
      logger.info('[EmailService] Verification email sent successfully via Gmail API', {
        to,
        messageId: result.messageId,
      });
      return result;
    }

    const mailTransporter = getTransporter();
    if (!mailTransporter) {
      logger.error('[EmailService] No email provider is configured; verification email was not sent', {
        to,
      });
      const error = new Error('Email delivery is unavailable. Please try again later.');
      error.statusCode = 503;
      throw error;
    }

    const sendPromise = mailTransporter.sendMail({ from, to, subject, text, html });
    let timeout;
    const timeoutPromise = new Promise((_, reject) => {
      timeout = setTimeout(
        () => reject(new Error('SMTP send timed out after 15s')),
        HTTP_SEND_TIMEOUT_MS,
      );
    });
    const info = await Promise.race([sendPromise, timeoutPromise]).finally(() =>
      clearTimeout(timeout),
    );
    logger.info('[EmailService] Verification email sent successfully', {
      to,
      messageId: info.messageId,
    });
    return { sent: true, messageId: info.messageId };
  } catch (err) {
    logger.error('[EmailService] Failed to send verification email', {
      to,
      error: err.message,
    });
    const error = new Error('Unable to deliver verification email. Please try again later.');
    error.statusCode = 503;
    throw error;
  }
}

async function sendDeletionRequestNotification({ requestId, email, phone, createdAt }) {
  const from = configuredFromAddress();
  const subject = `Data deletion request ${requestId} - Clients Hub`;
  const text = [
    'A data deletion request was submitted.',
    `Request ID: ${requestId}`,
    `Email: ${email}`,
    `Phone: ${phone}`,
    `Submitted: ${new Date(createdAt).toISOString()}`,
    '',
    'Verify ownership before deleting account data.',
  ].join('\n');

  try {
    if (gmailApiConfigured()) {
      return await sendWithGmailApi({
        from,
        to: 'istudio2512@gmail.com',
        replyTo: email,
        subject,
        text,
      });
    }

    const mailTransporter = getTransporter();
    if (!mailTransporter) {
      return { sent: false, reason: 'email_provider_not_configured' };
    }

    const info = await mailTransporter.sendMail({
      from,
      to: 'istudio2512@gmail.com',
      replyTo: email,
      subject,
      text,
    });
    return { sent: true, messageId: info.messageId };
  } catch (error) {
    return { sent: false, reason: 'delivery_failed', error };
  }
}

module.exports = {
  sendVerificationEmail,
  sendDeletionRequestNotification,
};
