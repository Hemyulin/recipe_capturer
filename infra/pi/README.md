# CookBuk Pi Infra

## Target Shape

- Run the API in Docker.
- Store SQLite data in a named volume or `/srv/cookbuk/data`.
- Reach the API over Tailscale for the MVP.
- Back up the SQLite file on a schedule before exposing the service broadly.

## First Deployment Checklist

1. Install Tailscale on the Pi and both phones.
2. Run the backend with `COOKBUK_HOST=0.0.0.0`.
3. Seed demo data if needed with `pnpm seed:demo`.
4. Run the Flutter app with `--dart-define=COOKBUK_API_BASE_URL=http://<pi-tailnet-name>:3000`.
5. Create a daily database backup job.

Later, add a reverse proxy and simple shared auth before exposing the backend
beyond the private tailnet.
