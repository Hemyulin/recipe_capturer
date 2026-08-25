import { Injectable, OnModuleDestroy, OnModuleInit } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import Database = require("better-sqlite3");
import { mkdirSync, readFileSync } from "node:fs";
import { dirname, isAbsolute, join } from "node:path";

@Injectable()
export class DatabaseService implements OnModuleInit, OnModuleDestroy {
  private connection?: Database.Database;

  constructor(private readonly config: ConfigService) {}

  get db(): Database.Database {
    if (!this.connection) {
      throw new Error("Database is not initialized");
    }
    return this.connection;
  }

  onModuleInit() {
    const configuredPath = this.config.get<string>(
      "COOKBUK_DATABASE_PATH",
      "./data/cookbuk.sqlite",
    );
    const databasePath = isAbsolute(configuredPath)
      ? configuredPath
      : join(process.cwd(), configuredPath);

    mkdirSync(dirname(databasePath), { recursive: true });

    this.connection = new Database(databasePath);
    this.connection.pragma("foreign_keys = ON");
    this.connection.exec(
      readFileSync(join(process.cwd(), "schema.sql"), "utf8"),
    );
    this.ensureColumns();
    this.ensureDefaultHousehold();
  }

  onModuleDestroy() {
    this.connection?.close();
  }

  private ensureDefaultHousehold() {
    const householdId = this.config.get<string>(
      "COOKBUK_HOUSEHOLD_ID",
      "local-household",
    );
    const householdName = this.config.get<string>(
      "COOKBUK_HOUSEHOLD_NAME",
      "CookBuk Household",
    );

    this.db
      .prepare(
        `
        INSERT INTO households (id, name)
        VALUES (?, ?)
        ON CONFLICT(id) DO UPDATE SET name = excluded.name
        `,
      )
      .run(householdId, householdName);
  }

  private ensureColumns() {
    this.ensureColumn("recipes", "cook_count", "INTEGER NOT NULL DEFAULT 0");
    this.ensureColumn("recipes", "last_cooked_at", "TEXT");
    this.ensureColumn("recipes", "season", "TEXT");
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS recipe_images (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
        url TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS recipe_preparation_tasks (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL REFERENCES recipes(id) ON DELETE CASCADE,
        body TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      );
    `);
    this.ensureColumn(
      "recipe_ingredients",
      "exclude_from_shopping",
      "INTEGER NOT NULL DEFAULT 0",
    );
    this.ensureColumn("recipe_ingredients", "usage_note", "TEXT");
    this.ensureColumn(
      "meal_plan_slots",
      "slot_type",
      "TEXT NOT NULL DEFAULT 'recipe'",
    );
    this.ensureColumn(
      "meal_plan_slots",
      "extras_json",
      "TEXT NOT NULL DEFAULT '[]'",
    );
    this.ensureColumn(
      "meal_plan_slots",
      "recipe_extra_ids_json",
      "TEXT NOT NULL DEFAULT '[]'",
    );
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS shopping_stores (
        id TEXT PRIMARY KEY,
        household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (household_id, name)
      );

      CREATE TABLE IF NOT EXISTS shopping_items (
        id TEXT PRIMARY KEY,
        household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
        name TEXT NOT NULL,
        normalized_name TEXT NOT NULL,
        store_id TEXT REFERENCES shopping_stores(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (household_id, normalized_name)
      );

      CREATE TABLE IF NOT EXISTS manual_shopping_items (
        id TEXT PRIMARY KEY,
        household_id TEXT NOT NULL REFERENCES households(id) ON DELETE CASCADE,
        week_start TEXT NOT NULL,
        name TEXT NOT NULL,
        normalized_name TEXT NOT NULL,
        quantity_label TEXT,
        store_id TEXT REFERENCES shopping_stores(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      );
    `);
  }

  private ensureColumn(table: string, column: string, definition: string) {
    const columns = this.db.prepare(`PRAGMA table_info(${table})`).all() as {
      name: string;
    }[];

    if (columns.some((existingColumn) => existingColumn.name === column)) {
      return;
    }

    this.db.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${definition}`);
  }
}
