# CookBuk Backend

NestJS API for shared CookBuk household data. For the MVP it runs locally or on a
Raspberry Pi, stores data in SQLite, and is expected to be reached over
Tailscale.

## Stack

- NestJS REST API
- SQLite via `better-sqlite3`
- Environment-based config with `.env`
- `pnpm` for dependency management

## Local Development

```sh
pnpm install
cp .env.example .env
pnpm seed:demo
pnpm start:dev
```

Useful checks:

```sh
pnpm typecheck
pnpm build
pnpm seed:demo
```

If `better-sqlite3` native bindings are missing after install, approve/rebuild
the package:

```sh
pnpm approve-builds better-sqlite3
pnpm rebuild better-sqlite3
```

## Environment

`.env` is ignored by Git. Use `.env.example` as the template.

| Variable | Local default | Notes |
| --- | --- | --- |
| `COOKBUK_PORT` | `3000` | API port |
| `COOKBUK_HOST` | `127.0.0.1` | Use `0.0.0.0` on the Pi |
| `COOKBUK_DATABASE_PATH` | `./data/cookbuk.sqlite` | SQLite file path |
| `COOKBUK_IMAGE_STORAGE_PATH` | `./data/images` | Uploaded recipe image folder |
| `COOKBUK_HOUSEHOLD_ID` | `local-household` | MVP household scope |
| `COOKBUK_HOUSEHOLD_NAME` | `CookBuk Household` | Display/admin label |
| `COOKBUK_CORS_ORIGIN` | `*` | Comma-separated origins or `*` |

For Pi + Tailscale, run with `COOKBUK_HOST=0.0.0.0` and point the Flutter app at
the Pi's Tailscale hostname or `100.x.y.z` address.

## API

### Health

```sh
curl http://127.0.0.1:3000/health
```

### Recipes

```sh
curl http://127.0.0.1:3000/recipes
```

```sh
curl -X POST http://127.0.0.1:3000/recipes \
  -H 'Content-Type: application/json' \
  -d '{
    "title": "Pesto Pasta",
    "servings": 2,
    "ingredients": [
      { "name": "Pasta", "quantity": "200", "unit": "g" }
    ],
    "instructions": ["Cook pasta", "Stir through pesto"],
    "tags": ["dinner", "quick"]
  }'
```

Endpoints:

- `GET /recipes`
- `GET /recipes/:id`
- `POST /recipes`
- `PATCH /recipes/:id`
- `POST /recipes/:id/image` with multipart field `image`
- `DELETE /recipes/:id`

Delete currently archives recipes instead of hard-deleting them.

Uploaded images are stored on disk and served back from `/images/<filename>`.
Keep `COOKBUK_IMAGE_STORAGE_PATH` on persistent storage on the Pi, ideally next
to the SQLite database backup path.

### Meal Plan

Meal values are `breakfast`, `lunch`, and `dinner`.

```sh
curl 'http://127.0.0.1:3000/meal-plan?from=2026-08-23&to=2026-08-30'
```

Recipe slot:

```json
{ "slotType": "recipe", "recipeId": "..." }
```

Leftovers slot:

```json
{ "slotType": "leftovers" }
```

Clear slot:

```json
{ "slotType": "empty" }
```

Endpoints:

- `GET /meal-plan?from=YYYY-MM-DD&to=YYYY-MM-DD`
- `PUT /meal-plan/:date/:meal`
- `DELETE /meal-plan/:date/:meal`

## Database

`schema.sql` is applied on startup with `CREATE TABLE IF NOT EXISTS`. The
database service also adds a few expected columns for local DBs created before a
schema change.

Run `pnpm seed:demo` to load the demo recipes into the configured SQLite
database. The command is safe to rerun: recipes are upserted by id, and their
ingredients, steps, tags, and demo cook events are refreshed.

Tracked schema includes:

- households
- users
- recipes
- recipe tags, ingredients, and steps
- meal plan slots with `recipe`, `leftovers`, or `empty`
- cook events for future automatic statistics

## MVP TODO

- Add cooking-history creation when a completed day is closed.
- Add shopping-list generation from planned meals.
- Add simple household auth/shared token before exposing beyond Tailscale.
