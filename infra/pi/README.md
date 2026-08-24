# CookBuk Pi Infra

## Target Shape

- Run the API with Docker Compose.
- Store SQLite and uploaded images in `/srv/cookbuk/data`.
- Reach the API over Tailscale for the MVP.
- Protect API calls with `COOKBUK_SHARED_TOKEN`.
- Back up SQLite and images on a schedule.

## First Deployment Checklist

1. Install Tailscale on the Pi and both phones.
2. Install Docker and the Docker Compose plugin on the Pi.
3. Clone this repo on the Pi.
4. Create the persistent folders:

```sh
sudo mkdir -p /srv/cookbuk/data /srv/cookbuk/backups
sudo chown -R "$USER:$USER" /srv/cookbuk
```

5. Create the Pi env file:

```sh
cd infra/pi
cp .env.example .env
```

Set a real `COOKBUK_SHARED_TOKEN` in `infra/pi/.env`.
Set `OPENAI_API_KEY` too if you want AI recipe import from photos.

6. Build and start the backend:

```sh
docker compose up -d --build
docker compose logs -f cookbuk-backend
```

7. Check health:

```sh
curl http://127.0.0.1:3000/health
```

8. Seed demo data if needed:

```sh
docker compose exec cookbuk-backend node scripts/seed-demo-recipes.cjs
```

The seed command is safe to rerun; it refreshes the demo recipes by id.

9. Run the Flutter app with the Pi's Tailscale hostname or IP:

```sh
flutter run \
  --dart-define=COOKBUK_API_BASE_URL=http://<pi-tailnet-name>:3000 \
  --dart-define=COOKBUK_SHARED_TOKEN=<same-token-as-pi>
```

## Backup

Install `sqlite3` on the Pi, then run:

```sh
./backup-cookbuk.sh
```

To run it daily at 03:15:

```sh
crontab -e
```

Add:

```cron
15 3 * * * /path/to/recipe_capturer/infra/pi/backup-cookbuk.sh >/tmp/cookbuk-backup.log 2>&1
```

The script keeps 30 days of database and image backups by default.

## Useful Commands

```sh
docker compose ps
docker compose logs -f cookbuk-backend
docker compose pull
docker compose up -d --build
docker compose restart cookbuk-backend
docker compose down
```

## Notes

Keep the service on Tailscale for now. The shared token is a useful household
gate, but it is not a replacement for proper public-internet auth.
