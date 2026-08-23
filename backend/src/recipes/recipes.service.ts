import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { randomUUID } from "node:crypto";
import { existsSync, mkdirSync, unlinkSync, writeFileSync } from "node:fs";
import { extname, join, resolve } from "node:path";
import { DatabaseService } from "../database/database.service";
import { CreateRecipeDto, RecipeIngredientDto } from "./dto/create-recipe.dto";
import { UpdateRecipeDto } from "./dto/update-recipe.dto";

type RecipeRow = {
  id: string;
  title: string;
  description: string | null;
  servings: number;
  season: string | null;
  prep_minutes: number | null;
  cook_minutes: number | null;
  source_url: string | null;
  image_url: string | null;
  is_favorite: number;
  cook_count: number;
  last_cooked_at: string | null;
  created_at: string;
  updated_at: string;
};

type IngredientRow = {
  name: string;
  amount: number | null;
  unit: string | null;
  note: string | null;
  sort_order: number;
};

type StepRow = {
  body: string;
  sort_order: number;
};

export type UploadedRecipeImage = {
  originalname: string;
  mimetype: string;
  buffer: Buffer;
  size: number;
};

@Injectable()
export class RecipesService {
  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}

  findAll() {
    const rows = this.database.db
      .prepare(
        `
        SELECT *
        FROM recipes
        WHERE household_id = ? AND archived_at IS NULL
        ORDER BY created_at DESC
        `,
      )
      .all(this.householdId()) as RecipeRow[];

    return rows.map((row) => this.toApiRecipe(row));
  }

  findOne(id: string) {
    const row = this.findRecipeRow(id);
    if (!row) throw new NotFoundException("Recipe not found");
    return this.toApiRecipe(row);
  }

  create(input: CreateRecipeDto) {
    const id = randomUUID();
    const now = new Date().toISOString();
    const servings = input.servings ?? 2;

    const transaction = this.database.db.transaction(() => {
      this.database.db
        .prepare(
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
            created_at,
            updated_at
          )
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          `,
        )
        .run(
          id,
          this.householdId(),
          input.title.trim(),
          input.notes?.trim() || null,
          servings,
          input.season?.trim() || null,
          input.prepTimeMinutes ?? null,
          input.cookTimeMinutes ?? null,
          input.imagePaths?.[0] ?? null,
          input.isFavorite ? 1 : 0,
          now,
          now,
        );

      this.replaceRecipeChildren(id, input);
    });

    transaction();
    return this.findOne(id);
  }

  update(id: string, input: UpdateRecipeDto) {
    const existing = this.findRecipeRow(id);
    if (!existing) throw new NotFoundException("Recipe not found");

    const transaction = this.database.db.transaction(() => {
      this.database.db
        .prepare(
          `
          UPDATE recipes
          SET
            title = ?,
            description = ?,
            servings = ?,
            season = ?,
            prep_minutes = ?,
            cook_minutes = ?,
            image_url = ?,
            is_favorite = ?,
            updated_at = ?
          WHERE id = ? AND household_id = ?
          `,
        )
        .run(
          input.title?.trim() ?? existing.title,
          input.notes?.trim() ?? existing.description,
          input.servings ?? existing.servings,
          input.season?.trim() ?? existing.season,
          input.prepTimeMinutes ?? existing.prep_minutes,
          input.cookTimeMinutes ?? existing.cook_minutes,
          input.imagePaths?.[0] ?? existing.image_url,
          input.isFavorite == null
            ? existing.is_favorite
            : input.isFavorite
              ? 1
              : 0,
          new Date().toISOString(),
          id,
          this.householdId(),
        );

      this.replaceRecipeChildren(id, input);
    });

    transaction();
    return this.findOne(id);
  }

  archive(id: string) {
    const result = this.database.db
      .prepare(
        `
        UPDATE recipes
        SET archived_at = ?, updated_at = ?
        WHERE id = ? AND household_id = ? AND archived_at IS NULL
        `,
      )
      .run(
        new Date().toISOString(),
        new Date().toISOString(),
        id,
        this.householdId(),
      );

    if (result.changes === 0) {
      throw new NotFoundException("Recipe not found");
    }
  }

  setMainImage(id: string, image: UploadedRecipeImage) {
    const existing = this.findRecipeRow(id);
    if (!existing) throw new NotFoundException("Recipe not found");
    if (!image.buffer || image.buffer.length === 0) {
      throw new BadRequestException("Image file is empty");
    }
    if (!image.mimetype.startsWith("image/")) {
      throw new BadRequestException("Only image uploads are supported");
    }

    const storagePath = this.imageStoragePath();
    mkdirSync(storagePath, { recursive: true });

    const filename = `${id}-${randomUUID()}${this.imageExtension(image)}`;
    const targetPath = join(storagePath, filename);
    writeFileSync(targetPath, image.buffer);

    const imageUrl = `/images/${filename}`;
    this.database.db
      .prepare(
        `
        UPDATE recipes
        SET image_url = ?, updated_at = ?
        WHERE id = ? AND household_id = ? AND archived_at IS NULL
        `,
      )
      .run(imageUrl, new Date().toISOString(), id, this.householdId());

    this.deletePreviousStoredImage(existing.image_url);

    return this.findOne(id);
  }

  private findRecipeRow(id: string) {
    return this.database.db
      .prepare(
        `
        SELECT *
        FROM recipes
        WHERE id = ? AND household_id = ? AND archived_at IS NULL
        `,
      )
      .get(id, this.householdId()) as RecipeRow | undefined;
  }

  private replaceRecipeChildren(id: string, input: UpdateRecipeDto) {
    if (input.ingredients != null) {
      this.database.db
        .prepare("DELETE FROM recipe_ingredients WHERE recipe_id = ?")
        .run(id);
      const insert = this.database.db.prepare(
        `
        INSERT INTO recipe_ingredients (id, recipe_id, name, amount, unit, note, sort_order)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        `,
      );
      input.ingredients.forEach((ingredient, index) => {
        insert.run(
          randomUUID(),
          id,
          ingredient.name.trim(),
          this.parseAmount(ingredient),
          ingredient.unit?.trim() || null,
          ingredient.quantity?.trim() || null,
          index,
        );
      });
    }

    if (input.instructions != null) {
      this.database.db
        .prepare("DELETE FROM recipe_steps WHERE recipe_id = ?")
        .run(id);
      const insert = this.database.db.prepare(
        `
        INSERT INTO recipe_steps (id, recipe_id, body, sort_order)
        VALUES (?, ?, ?, ?)
        `,
      );
      input.instructions.forEach((step, index) => {
        insert.run(randomUUID(), id, step.trim(), index);
      });
    }

    if (input.tags != null) {
      this.database.db
        .prepare("DELETE FROM recipe_tags WHERE recipe_id = ?")
        .run(id);
      const insert = this.database.db.prepare(
        `
        INSERT INTO recipe_tags (recipe_id, tag)
        VALUES (?, ?)
        `,
      );
      input.tags.forEach((tag) => insert.run(id, tag.trim()));
    }
  }

  private toApiRecipe(row: RecipeRow) {
    return {
      id: row.id,
      title: row.title,
      notes: row.description ?? "",
      servings: row.servings,
      season: row.season ?? "",
      prepTimeMinutes: row.prep_minutes,
      cookTimeMinutes: row.cook_minutes,
      isFavorite: row.is_favorite === 1,
      imagePaths: row.image_url ? [row.image_url] : [],
      ingredients: this.ingredientsFor(row.id),
      instructions: this.instructionsFor(row.id),
      tags: this.tagsFor(row.id),
      cookCount: row.cook_count,
      lastCookedAt: row.last_cooked_at,
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  private ingredientsFor(recipeId: string) {
    const rows = this.database.db
      .prepare(
        `
        SELECT name, amount, unit, note, sort_order
        FROM recipe_ingredients
        WHERE recipe_id = ?
        ORDER BY sort_order ASC
        `,
      )
      .all(recipeId) as IngredientRow[];

    return rows.map((row) => ({
      name: row.name,
      quantity: row.note ?? (row.amount == null ? "" : String(row.amount)),
      unit: row.unit ?? "",
    }));
  }

  private instructionsFor(recipeId: string) {
    const rows = this.database.db
      .prepare(
        `
        SELECT body, sort_order
        FROM recipe_steps
        WHERE recipe_id = ?
        ORDER BY sort_order ASC
        `,
      )
      .all(recipeId) as StepRow[];

    return rows.map((row) => row.body);
  }

  private tagsFor(recipeId: string) {
    const rows = this.database.db
      .prepare(
        `
        SELECT tag
        FROM recipe_tags
        WHERE recipe_id = ?
        ORDER BY tag ASC
        `,
      )
      .all(recipeId) as { tag: string }[];

    return rows.map((row) => row.tag);
  }

  private parseAmount(ingredient: RecipeIngredientDto) {
    if (!ingredient.quantity) return null;
    const parsed = Number(ingredient.quantity.replace(",", "."));
    return Number.isFinite(parsed) ? parsed : null;
  }

  private householdId() {
    return this.config.get<string>("COOKBUK_HOUSEHOLD_ID", "local-household");
  }

  private imageStoragePath() {
    return resolve(
      process.cwd(),
      this.config.get<string>("COOKBUK_IMAGE_STORAGE_PATH", "./data/images"),
    );
  }

  private imageExtension(image: UploadedRecipeImage) {
    const mimeExtensions: Record<string, string> = {
      "image/gif": ".gif",
      "image/heic": ".heic",
      "image/jpeg": ".jpg",
      "image/png": ".png",
      "image/webp": ".webp",
    };
    const extension =
      mimeExtensions[image.mimetype] ||
      extname(image.originalname).toLowerCase();

    if (/^\.[a-z0-9]{1,8}$/.test(extension)) return extension;
    return ".jpg";
  }

  private deletePreviousStoredImage(imageUrl: string | null) {
    if (!imageUrl?.startsWith("/images/")) return;

    const filename = imageUrl.slice("/images/".length);
    if (filename.includes("/") || filename.includes("\\")) return;

    const filePath = join(this.imageStoragePath(), filename);
    if (!existsSync(filePath)) return;

    try {
      unlinkSync(filePath);
    } catch {
      // Replacing the database value is more important than cleaning old files.
    }
  }
}
