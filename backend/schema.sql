PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS households (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  display_name TEXT NOT NULL,
  email TEXT UNIQUE,
  password_hash TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS recipes (
  id TEXT PRIMARY KEY,
  household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  servings INTEGER NOT NULL DEFAULT 2,
  prep_minutes INTEGER,
  cook_minutes INTEGER,
  source_url TEXT,
  image_url TEXT,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  cook_count INTEGER NOT NULL DEFAULT 0,
  last_cooked_at TEXT,
  archived_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS recipe_tags (
  recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  tag TEXT NOT NULL,
  PRIMARY KEY (recipe_id, tag)
);

CREATE TABLE IF NOT EXISTS recipe_ingredients (
  id TEXT PRIMARY KEY,
  recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  amount REAL,
  unit TEXT,
  note TEXT,
  sort_order INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS recipe_steps (
  id TEXT PRIMARY KEY,
  recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  sort_order INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS meal_plan_slots (
  id TEXT PRIMARY KEY,
  household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  planned_for TEXT NOT NULL,
  meal TEXT NOT NULL,
  slot_type TEXT NOT NULL DEFAULT 'recipe',
  recipe_id TEXT REFERENCES recipes(id) ON DELETE SET NULL,
  UNIQUE (household_id, planned_for, meal)
);

CREATE TABLE IF NOT EXISTS recipe_cook_events (
  id TEXT PRIMARY KEY,
  household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
  cooked_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  meal TEXT,
  user_id TEXT REFERENCES users(id) ON DELETE SET NULL
);
