# CookBuk

CookBuk is a private household recipe and meal planning app. The Flutter app lives in
`frontend/`; the future Pi-hosted API and deployment notes live beside it.

## Layout

- `frontend/` - Flutter app for recipes, today's meals, weekly planning, and shopping.
- `backend/` - planned API service for shared household recipe data.
- `infra/pi/` - Raspberry Pi deployment notes and configuration.

## Frontend

```sh
cd frontend
flutter pub get
flutter run
flutter test
```

For a phone talking to the Pi or another machine on Tailscale, pass the backend
URL at build/run time:

```sh
flutter run \
  --dart-define=COOKBUK_API_BASE_URL=http://cookbuk-pi:3000 \
  --dart-define=COOKBUK_SHARED_TOKEN=<same-token-as-backend>
```

Debug builds have dev defaults for the Pi addresses and token. To override them
locally, create one config file instead of typing the token every time:

```sh
cd frontend
cp .env.example .env
```

Edit `.env` with your real Pi URL/token if needed. The file is ignored by git.
After that, start the app with:

```sh
./tool/run_dev.sh
```

You can still pass normal Flutter run arguments after it, for example
`./tool/run_dev.sh -d <device-id>`.

The older `cookbuk.local.json` style still works too, but `.env` is the
recommended local setup.

For VS Code/Cursor debugging with hot reload, choose the launch config
`CookBuk Flutter (.env)`. It runs from `frontend/` and passes
`--dart-define-from-file=frontend/.env`, so the debug button can use the same
token. If your IDE ignores that config, the app still falls back to the built-in
dev Pi addresses.

Use the Pi's Tailscale hostname or `100.x.y.z` address. The default is
`http://127.0.0.1:3000`, which is only right when the app and backend run on the
same machine.

To prefer your home Wi-Fi/LAN address and fall back to Tailscale when away, pass
multiple comma-separated URLs:

```sh
flutter run \
  --dart-define=COOKBUK_API_BASE_URLS=http://192.168.178.54:3000,http://pi-server.local:3000,http://pi-server:3000,http://100.125.110.4:3000 \
  --dart-define=COOKBUK_SHARED_TOKEN=<same-token-as-backend>
```

Useful local checks:

```sh
flutter analyze
flutter test
flutter build web
```

## Backend

The backend is the shared source of truth for recipes and meal plans. See
`backend/README.md` for local setup, seed data, and API details. See
`infra/pi/README.md` for Raspberry Pi deployment.
