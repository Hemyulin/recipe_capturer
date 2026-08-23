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
    this.ensureColumn(
      "meal_plan_slots",
      "slot_type",
      "TEXT NOT NULL DEFAULT 'recipe'",
    );
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
