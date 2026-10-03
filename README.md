# Lumen Studio

Photography studio app with Flutter on the frontend and a Node.js + MongoDB auth API.

Palette: [Color Hunt](https://colorhunt.co/palette/e23e5788304e522546311d3f) — `#E23E57`, `#88304E`, `#522546`, `#311D3F`.

## Run the API

```bash
cd server
copy .env.example .env
```

Put your MongoDB connection string in `server/.env` as `MONGODB_URI`. Until that is set, the API keeps accounts in memory so you can try login and signup immediately. Memory accounts reset when the server restarts.

```bash
npm install
npm run dev
```

The API listens on `http://localhost:5000`.

### Transactional email on Render

Render Free blocks outbound SMTP ports, so configure an HTTPS email provider such as Resend instead of Gmail SMTP:

```env
RESEND_API_KEY=re_...
RESEND_FROM="Clients Hub <onboarding@your-verified-domain.com>"
```

Verify the sender domain or address in Resend before deploying. When `RESEND_API_KEY` is present, the API sends verification and data-deletion emails through Resend over HTTPS. SMTP remains available as a local fallback when the Resend key is absent.

## Google Play review account

Set these environment variables on the deployed backend:

```env
PLAY_REVIEW_EMAIL=test@gmail.com
PLAY_REVIEW_PASSWORD=123456789
```

The API creates this account when it starts. If the email already exists, its password is reset to the configured value on startup. The password is stored as a bcrypt hash. Share these credentials with Google Play reviewers; the account uses the app's normal functionality.

Open `http://localhost:5000/api-docs/` for the interactive Swagger UI. The raw OpenAPI document is available at `http://localhost:5000/openapi.yaml`.

- `POST /api/auth/signup` — `{ username, phone, password }`
- `POST /api/auth/login` — `{ phone, password }`
- `GET /api/auth/me` — `Authorization: Bearer <token>`

## Run the app

```bash
cd mobile
flutter pub get
flutter run
```

The Android emulator uses `10.0.2.2:5000`. Chrome, iOS simulator, and desktop use `localhost:5000`. On a physical phone, run with:

```bash
flutter run --dart-define=API_BASE_URL=http://YOUR_LAN_IP:5000/api
```
