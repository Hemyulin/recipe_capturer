# CookBuk Backend

This folder is reserved for the Pi-hosted API that will let the household share
the same recipes instead of keeping everything local on one device.

## First API Surface

- Recipes: list, read, create, update, archive.
- Meal plan: assign or clear recipes for breakfast, lunch, and dinner.
- Shopping list: generate from planned meals, then check items off together.
- Household access: two user accounts with shared household data.

## Suggested First Stack

- REST JSON API.
- SQLite database stored on the Pi.
- Docker deployment with a persistent data volume.
- Caddy or nginx in front for HTTPS when exposed outside the home network.

See `schema.sql` for the first database sketch.
