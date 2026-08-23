import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { randomUUID } from "node:crypto";
import { DatabaseService } from "../database/database.service";
import { UpdateMealExtrasDto } from "./dto/update-meal-extras.dto";
import { UpsertMealSlotDto } from "./dto/upsert-meal-slot.dto";

type MealSlotRow = {
  planned_for: string;
  meal: string;
  slot_type: string;
  recipe_id: string | null;
  extras_json: string;
};

const meals = new Set(["breakfast", "lunch", "dinner"]);

@Injectable()
export class MealPlanService {
  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}

  findRange(from?: string, to?: string) {
    const today = new Date().toISOString().slice(0, 10);
    const start = this.normalizeDate(from ?? today);
    const end = this.normalizeDate(to ?? start);

    const rows = this.database.db
      .prepare(
        `
        SELECT planned_for, meal, slot_type, recipe_id, extras_json
        FROM meal_plan_slots
        WHERE household_id = ? AND planned_for BETWEEN ? AND ?
        ORDER BY planned_for ASC, meal ASC
        `,
      )
      .all(this.householdId(), start, end) as MealSlotRow[];

    return rows.map((row) => this.toApiSlot(row));
  }

  upsert(date: string, meal: string, input: UpsertMealSlotDto) {
    const plannedFor = this.normalizeDate(date);
    const normalizedMeal = this.normalizeMeal(meal);

    if (input.slotType === "empty") {
      return this.writeSlot(
        plannedFor,
        normalizedMeal,
        "empty",
        null,
        input.extras == null ? [] : this.normalizeExtras(input.extras),
      );
    }

    if (input.slotType === "recipe") {
      if (!input.recipeId) {
        throw new BadRequestException("recipeId is required for recipe slots");
      }
      this.ensureRecipeExists(input.recipeId);
    }

    const recipeId = input.slotType === "recipe" ? input.recipeId! : null;
    const extras =
      input.extras == null ? undefined : this.normalizeExtras(input.extras);

    return this.writeSlot(
      plannedFor,
      normalizedMeal,
      input.slotType,
      recipeId,
      extras,
    );
  }

  updateExtras(date: string, meal: string, input: UpdateMealExtrasDto) {
    const plannedFor = this.normalizeDate(date);
    const normalizedMeal = this.normalizeMeal(meal);
    const extras = this.normalizeExtras(input.extras);
    const existing = this.database.db
      .prepare(
        `
        SELECT planned_for, meal, slot_type, recipe_id, extras_json
        FROM meal_plan_slots
        WHERE household_id = ? AND planned_for = ? AND meal = ?
        `,
      )
      .get(this.householdId(), plannedFor, normalizedMeal) as
      MealSlotRow | undefined;

    if (!existing) {
      return this.writeSlot(plannedFor, normalizedMeal, "empty", null, extras);
    }

    return this.writeSlot(
      plannedFor,
      normalizedMeal,
      existing.slot_type as "recipe" | "leftovers" | "empty",
      existing.recipe_id,
      extras,
    );
  }

  clear(date: string, meal: string) {
    this.database.db
      .prepare(
        `
        DELETE FROM meal_plan_slots
        WHERE household_id = ? AND planned_for = ? AND meal = ?
        `,
      )
      .run(
        this.householdId(),
        this.normalizeDate(date),
        this.normalizeMeal(meal),
      );
  }

  closeDay(date: string) {
    const plannedFor = this.normalizeDate(date);
    const cookedAt = `${plannedFor}T12:00:00.000Z`;
    const householdId = this.householdId();
    const slots = this.database.db
      .prepare(
        `
        SELECT planned_for, meal, slot_type, recipe_id, extras_json
        FROM meal_plan_slots
        WHERE household_id = ?
          AND planned_for = ?
          AND slot_type = 'recipe'
          AND recipe_id IS NOT NULL
        ORDER BY meal ASC
        `,
      )
      .all(householdId, plannedFor) as MealSlotRow[];

    const transaction = this.database.db.transaction(() => {
      let recordedCount = 0;

      for (const slot of slots) {
        const result = this.database.db
          .prepare(
            `
            INSERT OR IGNORE INTO recipe_cook_events (
              id,
              household_id,
              recipe_id,
              cooked_at,
              meal
            )
            VALUES (?, ?, ?, ?, ?)
            `,
          )
          .run(randomUUID(), householdId, slot.recipe_id, cookedAt, slot.meal);

        if (result.changes === 0) continue;
        recordedCount += 1;
        this.refreshRecipeCookStats(slot.recipe_id!);
      }

      return recordedCount;
    });

    const recordedCount = transaction();
    return {
      plannedFor,
      recordedCount,
      skippedCount: slots.length - recordedCount,
    };
  }

  private writeSlot(
    plannedFor: string,
    meal: string,
    slotType: "recipe" | "leftovers" | "empty",
    recipeId: string | null,
    extras?: string[],
  ) {
    const extrasJson = extras == null ? null : JSON.stringify(extras);
    this.database.db
      .prepare(
        `
        INSERT INTO meal_plan_slots (id, household_id, planned_for, meal, slot_type, recipe_id, extras_json)
        VALUES (?, ?, ?, ?, ?, ?, COALESCE(?, '[]'))
        ON CONFLICT(household_id, planned_for, meal)
        DO UPDATE SET
          slot_type = excluded.slot_type,
          recipe_id = excluded.recipe_id,
          extras_json = COALESCE(?, meal_plan_slots.extras_json)
        `,
      )
      .run(
        randomUUID(),
        this.householdId(),
        plannedFor,
        meal,
        slotType,
        recipeId,
        extrasJson,
        extrasJson,
      );

    return {
      plannedFor,
      meal,
      slotType,
      recipeId,
      extras: extras ?? [],
    };
  }

  private ensureRecipeExists(recipeId: string) {
    const recipe = this.database.db
      .prepare(
        `
        SELECT id
        FROM recipes
        WHERE household_id = ? AND id = ? AND archived_at IS NULL
        `,
      )
      .get(this.householdId(), recipeId);

    if (!recipe) throw new NotFoundException("Recipe not found");
  }

  private refreshRecipeCookStats(recipeId: string) {
    this.database.db
      .prepare(
        `
        UPDATE recipes
        SET
          cook_count = (
            SELECT COUNT(*)
            FROM recipe_cook_events
            WHERE household_id = ? AND recipe_id = ?
          ),
          last_cooked_at = (
            SELECT MAX(cooked_at)
            FROM recipe_cook_events
            WHERE household_id = ? AND recipe_id = ?
          ),
          updated_at = ?
        WHERE household_id = ? AND id = ?
        `,
      )
      .run(
        this.householdId(),
        recipeId,
        this.householdId(),
        recipeId,
        new Date().toISOString(),
        this.householdId(),
        recipeId,
      );
  }

  private toApiSlot(row: MealSlotRow) {
    return {
      plannedFor: row.planned_for,
      meal: row.meal,
      slotType: row.slot_type,
      recipeId: row.recipe_id,
      extras: this.parseExtras(row.extras_json),
    };
  }

  private normalizeExtras(values: string[]) {
    return values
      .map((value) => value.trim())
      .filter((value) => value.length > 0)
      .slice(0, 8);
  }

  private parseExtras(value: string) {
    try {
      const parsed = JSON.parse(value);
      if (!Array.isArray(parsed)) return [];
      return this.normalizeExtras(parsed.map((item) => String(item)));
    } catch {
      return [];
    }
  }

  private normalizeDate(value: string) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      throw new BadRequestException("Date must be YYYY-MM-DD");
    }
    return value;
  }

  private normalizeMeal(value: string) {
    const normalized = value.toLowerCase();
    if (!meals.has(normalized)) {
      throw new BadRequestException("Meal must be breakfast, lunch, or dinner");
    }
    return normalized;
  }

  private householdId() {
    return this.config.get<string>("COOKBUK_HOUSEHOLD_ID", "local-household");
  }
}
