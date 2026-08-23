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

## Backend Direction

The backend should become the shared source of truth for the household: recipes,
meal plans, and shopping state. A small REST API backed by SQLite is enough for the
first Pi version, with simple household auth and regular database backups.
