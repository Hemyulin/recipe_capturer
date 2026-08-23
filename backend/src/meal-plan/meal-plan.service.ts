import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { randomUUID } from "node:crypto";
import { DatabaseService } from "../database/database.service";
import { UpsertMealSlotDto } from "./dto/upsert-meal-slot.dto";

type MealSlotRow = {
  planned_for: string;
  meal: string;
  slot_type: string;
  recipe_id: string | null;
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
        SELECT planned_for, meal, slot_type, recipe_id
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
      return this.writeSlot(plannedFor, normalizedMeal, "empty", null);
    }

    if (input.slotType === "recipe") {
      if (!input.recipeId) {
        throw new BadRequestException("recipeId is required for recipe slots");
      }
      this.ensureRecipeExists(input.recipeId);
    }

    const recipeId = input.slotType === "recipe" ? input.recipeId! : null;

    return this.writeSlot(plannedFor, normalizedMeal, input.slotType, recipeId);
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
        SELECT planned_for, meal, slot_type, recipe_id
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
  ) {
    this.database.db
      .prepare(
        `
        INSERT INTO meal_plan_slots (id, household_id, planned_for, meal, slot_type, recipe_id)
        VALUES (?, ?, ?, ?, ?, ?)
        ON CONFLICT(household_id, planned_for, meal)
        DO UPDATE SET slot_type = excluded.slot_type, recipe_id = excluded.recipe_id
        `,
      )
      .run(
        randomUUID(),
        this.householdId(),
        plannedFor,
        meal,
        slotType,
        recipeId,
      );

    return {
      plannedFor,
      meal,
      slotType,
      recipeId,
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
    };
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
