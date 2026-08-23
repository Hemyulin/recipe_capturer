const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const Database = require('better-sqlite3');

const envPath = path.join(process.cwd(), '.env');
if (fs.existsSync(envPath)) {
  for (const line of fs.readFileSync(envPath, 'utf8').split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const [key, ...valueParts] = trimmed.split('=');
    process.env[key] ??= valueParts.join('=');
  }
}

const databasePath = path.resolve(
  process.cwd(),
  process.env.COOKBUK_DATABASE_PATH ?? './data/cookbuk.sqlite',
);
const householdId = process.env.COOKBUK_HOUSEHOLD_ID ?? 'local-household';
const householdName =
  process.env.COOKBUK_HOUSEHOLD_NAME ?? 'CookBuk Household';
const seedPath = path.join(process.cwd(), 'seed/demo-recipes.json');
const recipes = JSON.parse(fs.readFileSync(seedPath, 'utf8'));

fs.mkdirSync(path.dirname(databasePath), { recursive: true });

const db = new Database(databasePath);
db.pragma('foreign_keys = ON');
db.exec(fs.readFileSync(path.join(process.cwd(), 'schema.sql'), 'utf8'));
ensureColumns();

const transaction = db.transaction(() => {
  db.prepare(
    `
    INSERT INTO households (id, name)
    VALUES (?, ?)
    ON CONFLICT(id) DO UPDATE SET name = excluded.name
    `,
  ).run(householdId, householdName);

  for (const recipe of recipes) {
    upsertRecipe(recipe);
  }
});

transaction();
db.close();

console.log(`Seeded ${recipes.length} demo recipes into ${databasePath}`);

function upsertRecipe(recipe) {
  db.prepare(
    `
    INSERT INTO recipes (
      id,
      household_id,
      title,
      description,
      servings,
      season,
      prep_minutes,
      cook_minutes,
      image_url,
      is_favorite,
      cook_count,
      last_cooked_at,
      created_at,
      updated_at
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      title = excluded.title,
      description = excluded.description,
      servings = excluded.servings,
      season = excluded.season,
      prep_minutes = excluded.prep_minutes,
      cook_minutes = excluded.cook_minutes,
      image_url = excluded.image_url,
      is_favorite = excluded.is_favorite,
      cook_count = excluded.cook_count,
      last_cooked_at = excluded.last_cooked_at,
      archived_at = NULL,
      updated_at = excluded.updated_at
    `,
  ).run(
    recipe.id,
    householdId,
    recipe.title,
    recipe.notes || null,
    recipe.servings ?? 2,
    recipe.season || null,
    recipe.prepTimeMinutes ?? null,
    recipe.cookTimeMinutes ?? null,
    recipe.imagePaths?.[0] ?? null,
    recipe.isFavorite ? 1 : 0,
    recipe.cookCount ?? 0,
    recipe.lastCookedAt ?? null,
    recipe.createdAt,
    new Date().toISOString(),
  );

  db.prepare('DELETE FROM recipe_ingredients WHERE recipe_id = ?').run(
    recipe.id,
  );
  db.prepare('DELETE FROM recipe_steps WHERE recipe_id = ?').run(recipe.id);
  db.prepare('DELETE FROM recipe_tags WHERE recipe_id = ?').run(recipe.id);
  db.prepare('DELETE FROM recipe_cook_events WHERE recipe_id = ?').run(
    recipe.id,
  );

  const insertIngredient = db.prepare(
    `
    INSERT INTO recipe_ingredients (id, recipe_id, name, amount, unit, note, sort_order)
    VALUES (?, ?, ?, ?, ?, ?, ?)
    `,
  );
  recipe.ingredients?.forEach((ingredient, index) => {
    insertIngredient.run(
      crypto.randomUUID(),
      recipe.id,
      ingredient.name,
      parseAmount(ingredient.quantity),
      ingredient.unit || null,
      ingredient.quantity || null,
      index,
    );
  });

  const insertStep = db.prepare(
    `
    INSERT INTO recipe_steps (id, recipe_id, body, sort_order)
    VALUES (?, ?, ?, ?)
    `,
  );
  recipe.instructions?.forEach((step, index) => {
    insertStep.run(crypto.randomUUID(), recipe.id, step, index);
  });

  const insertTag = db.prepare(
    `
    INSERT INTO recipe_tags (recipe_id, tag)
    VALUES (?, ?)
    `,
  );
  recipe.tags?.forEach((tag) => insertTag.run(recipe.id, tag));

  const insertCookEvent = db.prepare(
    `
    INSERT INTO recipe_cook_events (id, household_id, recipe_id, cooked_at, meal)
    VALUES (?, ?, ?, ?, ?)
    `,
  );
  recipe.cookEvents?.forEach((event) => {
    insertCookEvent.run(
      crypto.randomUUID(),
      householdId,
      recipe.id,
      event.cookedAt,
      event.mealType || null,
    );
  });
}

function parseAmount(value) {
  if (!value) return null;
  const parsed = Number(String(value).replace(',', '.'));
  return Number.isFinite(parsed) ? parsed : null;
}

function ensureColumns() {
  ensureColumn('recipes', 'cook_count', 'INTEGER NOT NULL DEFAULT 0');
  ensureColumn('recipes', 'last_cooked_at', 'TEXT');
  ensureColumn('recipes', 'season', 'TEXT');
  ensureColumn(
    'meal_plan_slots',
    'slot_type',
    "TEXT NOT NULL DEFAULT 'recipe'",
  );
}

function ensureColumn(table, column, definition) {
  const columns = db.prepare(`PRAGMA table_info(${table})`).all();
  if (columns.some((existingColumn) => existingColumn.name === column)) return;
  db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
}
