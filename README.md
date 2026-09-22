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
