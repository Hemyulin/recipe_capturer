# CookBuk Pi Infra

This folder will hold the Raspberry Pi deployment setup once the backend exists.

## Target Shape

- Run the API in Docker.
- Store SQLite data in a named volume or `/srv/cookbuk/data`.
- Put Caddy or nginx in front of the API.
- Back up the SQLite file on a schedule before exposing the service broadly.

## First Deployment Checklist

1. Build the backend image on the Pi.
2. Mount persistent storage for the database.
3. Add a reverse proxy route such as `cookbuk.local` or a private Tailscale URL.
4. Create a daily database backup job.
