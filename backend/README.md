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
| `COOKBUK_SHARED_TOKEN` | empty | Optional API token; set this on the Pi |
| `COOKBUK_HOUSEHOLD_ID` | `local-household` | MVP household scope |
| `COOKBUK_HOUSEHOLD_NAME` | `CookBuk Household` | Display/admin label |
| `COOKBUK_CORS_ORIGIN` | `*` | Comma-separated origins or `*` |

For Pi + Tailscale, run with `COOKBUK_HOST=0.0.0.0` and point the Flutter app at
the Pi's Tailscale hostname or `100.x.y.z` address.

If `COOKBUK_SHARED_TOKEN` is set, all API routes except `/health` require the
same value in the `x-cookbuk-token` header. Build or run Flutter with matching
dart defines:

```sh
flutter run \
  --dart-define=COOKBUK_API_BASE_URL=http://your-pi:3000 \
  --dart-define=COOKBUK_SHARED_TOKEN=your-secret
```

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
{
  "slotType": "recipe",
  "recipeId": "...",
  "extras": ["Brot", "Salat"],
  "recipeExtraIds": ["..."]
}
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
- `POST /meal-plan/close-day/:date`
- `PUT /meal-plan/:date/:meal`
- `PUT /meal-plan/:date/:meal/extras`
- `DELETE /meal-plan/:date/:meal`

Meal slots can carry lightweight text extras such as bread, salad, or quark.
They can also carry recipe extras for side dishes such as hummus, dips, cakes, or
anything else that should still behave like a standalone recipe. Text extras are
included as plain shopping list items; recipe extras contribute their ingredients
to the shopping list.

Closing a day creates cook-history events for each planned recipe and recipe
extra on that date. It ignores leftovers and empty slots, and it is safe to call
repeatedly.

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
- cook events for automatic statistics

## MVP TODO

- Add manual shopping-list items.
- Add Pi deployment and backup scripts.
