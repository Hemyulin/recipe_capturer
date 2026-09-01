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
  recipe_extra_ids_json: string;
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
        SELECT planned_for, meal, slot_type, recipe_id, extras_json, recipe_extra_ids_json
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
        [],
      );
    }

    if (input.slotType === "away") {
      return this.writeSlot(
        plannedFor,
        normalizedMeal,
        "away",
        null,
        input.extras == null ? [] : this.normalizeExtras(input.extras),
        [],
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
    const recipeExtraIds =
      input.recipeExtraIds == null
        ? undefined
        : this.normalizeRecipeExtraIds(input.recipeExtraIds, recipeId);

    return this.writeSlot(
      plannedFor,
      normalizedMeal,
      input.slotType,
      recipeId,
      extras,
      recipeExtraIds,
    );
  }

  updateExtras(date: string, meal: string, input: UpdateMealExtrasDto) {
    const plannedFor = this.normalizeDate(date);
    const normalizedMeal = this.normalizeMeal(meal);
    const extras = this.normalizeExtras(input.extras);
    const recipeExtraIds = this.normalizeRecipeExtraIds(
      input.recipeExtraIds ?? [],
      null,
    );
    const existing = this.database.db
      .prepare(
        `
        SELECT planned_for, meal, slot_type, recipe_id, extras_json, recipe_extra_ids_json
        FROM meal_plan_slots
        WHERE household_id = ? AND planned_for = ? AND meal = ?
        `,
      )
      .get(this.householdId(), plannedFor, normalizedMeal) as
      MealSlotRow | undefined;

    if (!existing) {
      return this.writeSlot(
        plannedFor,
        normalizedMeal,
        "empty",
        null,
        extras,
        recipeExtraIds,
      );
    }

    return this.writeSlot(
      plannedFor,
      normalizedMeal,
      existing.slot_type as "recipe" | "leftovers" | "away" | "empty",
      existing.recipe_id,
      extras,
      recipeExtraIds.filter((id) => id !== existing.recipe_id),
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
        SELECT planned_for, meal, slot_type, recipe_id, extras_json, recipe_extra_ids_json
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
      let expectedCount = 0;

      for (const slot of slots) {
        const recipeIds = [
          ...new Set([
            slot.recipe_id!,
            ...this.parseRecipeExtraIds(slot.recipe_extra_ids_json),
          ]),
        ];
        expectedCount += recipeIds.length;

        for (const recipeId of recipeIds) {
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
            .run(randomUUID(), householdId, recipeId, cookedAt, slot.meal);

          if (result.changes === 0) continue;
          recordedCount += 1;
          this.refreshRecipeCookStats(recipeId);
        }
      }

      return { recordedCount, expectedCount };
    });

    const { recordedCount, expectedCount } = transaction();
    return {
      plannedFor,
      recordedCount,
      skippedCount: expectedCount - recordedCount,
    };
  }

  private writeSlot(
    plannedFor: string,
    meal: string,
    slotType: "recipe" | "leftovers" | "away" | "empty",
    recipeId: string | null,
    extras?: string[],
    recipeExtraIds?: string[],
  ) {
    const extrasJson = extras == null ? null : JSON.stringify(extras);
    const recipeExtraIdsJson =
      recipeExtraIds == null ? null : JSON.stringify(recipeExtraIds);
    this.database.db
      .prepare(
        `
        INSERT INTO meal_plan_slots (id, household_id, planned_for, meal, slot_type, recipe_id, extras_json, recipe_extra_ids_json)
        VALUES (?, ?, ?, ?, ?, ?, COALESCE(?, '[]'), COALESCE(?, '[]'))
        ON CONFLICT(household_id, planned_for, meal)
        DO UPDATE SET
          slot_type = excluded.slot_type,
          recipe_id = excluded.recipe_id,
          extras_json = COALESCE(?, meal_plan_slots.extras_json),
          recipe_extra_ids_json = COALESCE(?, meal_plan_slots.recipe_extra_ids_json)
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
        recipeExtraIdsJson,
        extrasJson,
        recipeExtraIdsJson,
      );

    const row = this.database.db
      .prepare(
        `
        SELECT planned_for, meal, slot_type, recipe_id, extras_json, recipe_extra_ids_json
        FROM meal_plan_slots
        WHERE household_id = ? AND planned_for = ? AND meal = ?
        `,
      )
      .get(this.householdId(), plannedFor, meal) as MealSlotRow;

    return this.toApiSlot(row);
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
      recipeExtraIds: this.parseRecipeExtraIds(row.recipe_extra_ids_json),
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

  private normalizeRecipeExtraIds(
    values: string[],
    mainRecipeId: string | null,
  ) {
    const ids = [
      ...new Set(
        values
          .map((value) => value.trim())
          .filter((value) => value.length > 0 && value !== mainRecipeId),
      ),
    ].slice(0, 8);

    ids.forEach((id) => this.ensureRecipeExists(id));
    return ids;
  }

  private parseRecipeExtraIds(value: string) {
    try {
      const parsed = JSON.parse(value);
      if (!Array.isArray(parsed)) return [];
      return [
        ...new Set(
          parsed
            .map((item) => String(item).trim())
            .filter((item) => item.length > 0),
        ),
      ].slice(0, 8);
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
