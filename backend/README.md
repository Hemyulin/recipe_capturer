# CookBuk Backend

This folder contains the Pi-hosted API that will let the household share the same
recipes instead of keeping everything local on one device.

## First API Surface

- Recipes: list, read, create, update, archive.
- Meal plan: assign or clear recipes for breakfast, lunch, and dinner.
- Cooking history: record completed meal plan slots with date and meal type.
- Shopping list: generate from planned meals, then check items off together.
- Household access: two user accounts with shared household data.

## Suggested First Stack

- NestJS REST JSON API.
- SQLite database stored on the Pi.
- Docker deployment with a persistent data volume.
- Caddy or nginx in front for HTTPS when exposed outside the home network.

## Local Development

```sh
pnpm install
cp .env.example .env
pnpm start:dev
```

The local `.env` is ignored by Git. Change `COOKBUK_DATABASE_PATH` for local
testing or Pi hosting without changing source code.

For a Pi/Tailscale deployment, set `COOKBUK_HOST=0.0.0.0`. For local
development, `127.0.0.1` is usually nicer.

Useful endpoints:

- `GET /health`
- `GET /recipes`
- `POST /recipes`
- `PATCH /recipes/:id`
- `DELETE /recipes/:id`
- `GET /meal-plan?from=2026-08-23&to=2026-08-30`
- `PUT /meal-plan/:date/:meal`
- `DELETE /meal-plan/:date/:meal`

Meal slot payloads:

```json
{ "slotType": "recipe", "recipeId": "..." }
{ "slotType": "leftovers" }
{ "slotType": "empty" }
```

See `schema.sql` for the first database sketch.
