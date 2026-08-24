import {
  BadRequestException,
  Injectable,
  ServiceUnavailableException,
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
  usage_note: string | null;
  exclude_from_shopping: number;
  sort_order: number;
};

type StepRow = {
  body: string;
  sort_order: number;
};

type CookEventRow = {
  cooked_at: string;
  meal: string | null;
};

type MealPlanReferenceRow = {
  id: string;
  recipe_extra_ids_json: string;
};

export type UploadedRecipeImage = {
  originalname: string;
  mimetype: string;
  buffer: Buffer;
  size: number;
};

type ImportedRecipeDraft = {
  title: string;
  notes?: string;
  servings?: number;
  season?: string;
  prepTimeMinutes?: number;
  cookTimeMinutes?: number;
  ingredients?: RecipeIngredientDto[];
  instructions?: string[];
  tags?: string[];
  confidenceNotes?: string[];
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

  delete(id: string) {
    const existing = this.findAnyRecipeRow(id);

    const transaction = this.database.db.transaction(() => {
      this.clearMealPlanReferences(id);
      const result = this.database.db
        .prepare(
          `
          DELETE FROM recipes
          WHERE id = ? AND household_id = ?
          `,
        )
        .run(id, this.householdId());

      if (result.changes === 0) {
        throw new NotFoundException("Recipe not found");
      }
    });

    transaction();
    this.deletePreviousStoredImage(existing.image_url);
  }

  archive(id: string) {
    this.delete(id);
  }

  private clearMealPlanReferences(recipeId: string) {
    this.database.db
      .prepare(
        `
        UPDATE meal_plan_slots
        SET slot_type = 'empty', recipe_id = NULL
        WHERE household_id = ? AND recipe_id = ?
        `,
      )
      .run(this.householdId(), recipeId);

    const rows = this.database.db
      .prepare(
        `
        SELECT id, recipe_extra_ids_json
        FROM meal_plan_slots
        WHERE household_id = ? AND recipe_extra_ids_json != '[]'
        `,
      )
      .all(this.householdId()) as MealPlanReferenceRow[];

    const update = this.database.db.prepare(
      `
      UPDATE meal_plan_slots
      SET recipe_extra_ids_json = ?
      WHERE id = ?
      `,
    );

    for (const row of rows) {
      const recipeExtraIds = this.parseRecipeExtraIds(
        row.recipe_extra_ids_json,
      );
      const filteredIds = recipeExtraIds.filter((id) => id !== recipeId);
      if (filteredIds.length === recipeExtraIds.length) continue;
      update.run(JSON.stringify(filteredIds), row.id);
    }
  }

  private parseRecipeExtraIds(value: string) {
    try {
      const parsed = JSON.parse(value);
      if (!Array.isArray(parsed)) return [];
      return parsed.map((item) => String(item).trim()).filter(Boolean);
    } catch {
      return [];
    }
  }

  private findAnyRecipeRow(id: string) {
    const row = this.database.db
      .prepare(
        `
        SELECT *
        FROM recipes
        WHERE id = ? AND household_id = ?
        `,
      )
      .get(id, this.householdId()) as RecipeRow | undefined;

    if (!row) {
      throw new NotFoundException("Recipe not found");
    }

    return row;
  }

  async importFromPhoto(image: UploadedRecipeImage) {
    return this.importFromPhotos([image]);
  }

  async importFromPhotos(images: UploadedRecipeImage[]) {
    if (images.length === 0) {
      throw new BadRequestException("Image file is required");
    }
    if (images.length > 5) {
      throw new BadRequestException("A maximum of 5 images is supported");
    }
    for (const image of images) {
      this.validateRecipeImage(image);
    }

    const apiKey = this.config.get<string>("OPENAI_API_KEY")?.trim();
    if (!apiKey) {
      throw new ServiceUnavailableException(
        "AI recipe import is not configured. Set OPENAI_API_KEY on the backend.",
      );
    }

    const model =
      this.config.get<string>("COOKBUK_OPENAI_RECIPE_MODEL")?.trim() ||
      "gpt-5-mini";
    const imageUrls = images.map(
      (image) =>
        `data:${this.imageMimeType(image)};base64,${image.buffer.toString("base64")}`,
    );

    const response = await this.createOpenAiRecipeDraft(
      model,
      apiKey,
      imageUrls,
    );

    if (!response.ok) {
      throw new ServiceUnavailableException(
        await this.openAiErrorMessage(response),
      );
    }

    const payload = (await response.json()) as unknown;
    const outputText = this.extractOpenAiOutputText(payload);
    if (!outputText) {
      throw new ServiceUnavailableException(
        "AI recipe import returned no text.",
      );
    }

    try {
      return this.normalizeImportedRecipeDraft(JSON.parse(outputText));
    } catch {
      throw new ServiceUnavailableException(
        "AI recipe import returned invalid recipe data.",
      );
    }
  }

  private validateRecipeImage(image: UploadedRecipeImage) {
    if (!image.buffer || image.buffer.length === 0) {
      throw new BadRequestException("Image file is empty");
    }
    if (!this.isSupportedImage(image)) {
      throw new BadRequestException("Only image uploads are supported");
    }
  }

  private async openAiErrorMessage(response: Response) {
    const fallback = `AI recipe import failed. HTTP ${response.status}.`;
    let payload: unknown;
    try {
      payload = await response.json();
    } catch {
      return fallback;
    }

    const error = (payload as { error?: unknown }).error as
      | {
          code?: unknown;
          message?: unknown;
          type?: unknown;
        }
      | undefined;
    const code = typeof error?.code === "string" ? error.code : "";
    const type = typeof error?.type === "string" ? error.type : "";
    const message = typeof error?.message === "string" ? error.message : "";

    if (response.status === 429) {
      if (code === "insufficient_quota" || type === "insufficient_quota") {
        return "AI recipe import failed. OpenAI quota is exhausted or billing is not active for this project.";
      }
      return "AI recipe import failed. OpenAI rate limit reached. Wait a bit or check the project's usage limits.";
    }

    if (!code && !type && !message) return fallback;
    return [
      fallback,
      code ? `code=${code}` : "",
      type ? `type=${type}` : "",
      message ? `message=${message}` : "",
    ]
      .filter(Boolean)
      .join(" ");
  }

  private async createOpenAiRecipeDraft(
    model: string,
    apiKey: string,
    imageUrls: string[],
  ) {
    try {
      return await fetch("https://api.openai.com/v1/responses", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          input: [
            {
              role: "developer",
              content:
                "You extract editable household recipes from photos. Return only fields that are visible or strongly implied. Prefer German recipe text when the photo is German. Never invent precise quantities if they are unreadable; leave quantity or unit empty instead. Keep notes short and practical; do not copy long cookbook introductions. Put ingredient preparation in the name when it identifies the ingredient, for example 'garlic cloves, crushed'. Put optional usage notes, garnish notes, alternatives, or parentheticals such as 'plus extra to finish' in ingredient.note, not in ingredient.name. Keep water in the ingredients if the recipe uses it, but set excludeFromShopping=true for water, boiling water, tap water, ice, and other household basics that do not belong on a grocery list. Prefer tags from this household set: breakfast, lunch, dinner, main, side, dip, sauce, bread, dessert, snack, vegetarian, vegan, meat, fish, one_pot, quick, rice, pasta, soup, salad, baking.",
            },
            {
              role: "user",
              content: [
                {
                  type: "input_text",
                  text: "Create one CookBuk recipe draft from these image(s). If there are multiple images, treat them as pages of the same recipe in order. Include confidenceNotes for uncertain parts.",
                },
                ...imageUrls.map((imageUrl) => ({
                  type: "input_image",
                  image_url: imageUrl,
                  detail: "high",
                })),
              ],
            },
          ],
          text: {
            format: {
              type: "json_schema",
              name: "cookbuk_recipe_draft",
              strict: true,
              schema: {
                type: "object",
                additionalProperties: false,
                required: [
                  "title",
                  "notes",
                  "servings",
                  "season",
                  "prepTimeMinutes",
                  "cookTimeMinutes",
                  "ingredients",
                  "instructions",
                  "tags",
                  "confidenceNotes",
                ],
                properties: {
                  title: { type: "string" },
                  notes: { type: "string" },
                  servings: { type: ["integer", "null"], minimum: 1 },
                  season: { type: "string" },
                  prepTimeMinutes: { type: ["integer", "null"], minimum: 0 },
                  cookTimeMinutes: { type: ["integer", "null"], minimum: 0 },
                  ingredients: {
                    type: "array",
                    items: {
                      type: "object",
                      additionalProperties: false,
                      required: [
                        "name",
                        "quantity",
                        "unit",
                        "note",
                        "excludeFromShopping",
                      ],
                      properties: {
                        name: { type: "string" },
                        quantity: { type: "string" },
                        unit: { type: "string" },
                        note: { type: "string" },
                        excludeFromShopping: { type: "boolean" },
                      },
                    },
                  },
                  instructions: {
                    type: "array",
                    items: { type: "string" },
                  },
                  tags: {
                    type: "array",
                    items: { type: "string" },
                  },
                  confidenceNotes: {
                    type: "array",
                    items: { type: "string" },
                  },
                },
              },
            },
          },
        }),
      });
    } catch {
      throw new ServiceUnavailableException(
        "AI recipe import could not reach OpenAI.",
      );
    }
  }

  setMainImage(id: string, image: UploadedRecipeImage) {
    const existing = this.findRecipeRow(id);
    if (!existing) throw new NotFoundException("Recipe not found");
    if (!image.buffer || image.buffer.length === 0) {
      throw new BadRequestException("Image file is empty");
    }
    if (!this.isSupportedImage(image)) {
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
        INSERT INTO recipe_ingredients (id, recipe_id, name, amount, unit, note, usage_note, exclude_from_shopping, sort_order)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        `,
      );
      input.ingredients.forEach((ingredient, index) => {
        const quantity = ingredient.quantity?.trim() || "";
        const amount = this.parseAmount(ingredient);
        insert.run(
          randomUUID(),
          id,
          ingredient.name.trim(),
          amount,
          ingredient.unit?.trim() || null,
          this.rawQuantityNote(quantity, amount),
          ingredient.note?.trim() || null,
          ingredient.excludeFromShopping || this.isHouseholdBasic(ingredient)
            ? 1
            : 0,
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
      cookEvents: this.cookEventsFor(row.id),
      createdAt: row.created_at,
      updatedAt: row.updated_at,
    };
  }

  private ingredientsFor(recipeId: string) {
    const rows = this.database.db
      .prepare(
        `
        SELECT name, amount, unit, note, usage_note, exclude_from_shopping, sort_order
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
      note: row.usage_note ?? "",
      excludeFromShopping: row.exclude_from_shopping === 1,
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

  private cookEventsFor(recipeId: string) {
    const rows = this.database.db
      .prepare(
        `
        SELECT cooked_at, meal
        FROM recipe_cook_events
        WHERE recipe_id = ? AND household_id = ?
        ORDER BY cooked_at DESC
        `,
      )
      .all(recipeId, this.householdId()) as CookEventRow[];

    return rows.map((row) => ({
      cookedAt: row.cooked_at,
      mealType: row.meal ?? "",
    }));
  }

  private parseAmount(ingredient: RecipeIngredientDto) {
    if (!ingredient.quantity) return null;
    const parsed = Number(ingredient.quantity.replace(",", "."));
    return Number.isFinite(parsed) ? parsed : null;
  }

  private rawQuantityNote(quantity: string, amount: number | null) {
    if (!quantity || amount == null) return quantity || null;
    return quantity.replace(",", ".") === String(amount) ? null : quantity;
  }

  private isHouseholdBasic(ingredient: RecipeIngredientDto) {
    const name = ingredient.name.trim().toLowerCase();
    const normalizedName = name.replace(/[^\p{L}\p{N}]+/gu, " ").trim();
    return [
      "water",
      "boiling water",
      "tap water",
      "cold water",
      "hot water",
      "ice",
      "wasser",
      "kochendes wasser",
      "leitungswasser",
      "kaltes wasser",
      "heisses wasser",
      "heißes wasser",
      "eis",
    ].includes(normalizedName);
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

  private isSupportedImage(image: UploadedRecipeImage) {
    if (image.mimetype.startsWith("image/")) return true;
    return this.supportedImageExtensions().has(
      extname(image.originalname).toLowerCase(),
    );
  }

  private imageMimeType(image: UploadedRecipeImage) {
    if (image.mimetype.startsWith("image/")) return image.mimetype;
    return (
      {
        ".gif": "image/gif",
        ".heic": "image/heic",
        ".jpeg": "image/jpeg",
        ".jpg": "image/jpeg",
        ".png": "image/png",
        ".webp": "image/webp",
      }[extname(image.originalname).toLowerCase()] ?? "image/jpeg"
    );
  }

  private supportedImageExtensions() {
    return new Set([".gif", ".heic", ".jpeg", ".jpg", ".png", ".webp"]);
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

  private extractOpenAiOutputText(payload: unknown) {
    const response = payload as {
      output_text?: unknown;
      output?: { content?: { text?: unknown }[] }[];
    };
    if (typeof response.output_text === "string") {
      return response.output_text.trim();
    }

    return (response.output ?? [])
      .flatMap((item) => item.content ?? [])
      .map((content) => content.text)
      .filter((text): text is string => typeof text === "string")
      .join("\n")
      .trim();
  }

  private normalizeImportedRecipeDraft(value: unknown): ImportedRecipeDraft {
    const draft = value as ImportedRecipeDraft;
    const title = this.cleanText(draft.title) || "Unbenanntes Rezept";
    const ingredients = (draft.ingredients ?? [])
      .map((ingredient) => {
        const splitName = this.splitIngredientUsageNote(
          this.cleanText(ingredient.name),
        );
        return {
          name: splitName.name,
          quantity: this.cleanText(ingredient.quantity),
          unit: this.cleanText(ingredient.unit),
          note: this.cleanText(ingredient.note) || splitName.note,
          excludeFromShopping:
            ingredient.excludeFromShopping || this.isHouseholdBasic(ingredient),
        };
      })
      .filter((ingredient) => ingredient.name.length > 0)
      .slice(0, 40);
    const instructions = (draft.instructions ?? [])
      .map((step) => this.cleanText(step))
      .filter((step) => step.length > 0)
      .slice(0, 30);
    const tags = (draft.tags ?? [])
      .map((tag) => this.cleanTag(tag))
      .filter((tag) => tag.length > 0)
      .filter((tag, index, values) => values.indexOf(tag) === index)
      .slice(0, 8);
    const confidenceNotes = (draft.confidenceNotes ?? [])
      .map((note) => this.cleanText(note))
      .filter((note) => note.length > 0)
      .slice(0, 8);

    return {
      title,
      notes: this.cleanText(draft.notes),
      servings: this.positiveIntOrUndefined(draft.servings),
      season: this.cleanText(draft.season),
      prepTimeMinutes: this.nonNegativeIntOrUndefined(draft.prepTimeMinutes),
      cookTimeMinutes: this.nonNegativeIntOrUndefined(draft.cookTimeMinutes),
      ingredients,
      instructions,
      tags,
      confidenceNotes,
    };
  }

  private cleanText(value: unknown) {
    return typeof value === "string" ? value.trim() : "";
  }

  private splitIngredientUsageNote(name: string) {
    const match = name.match(/^(.*?)\s*\(([^)]*)\)\s*$/);
    if (!match) return { name, note: "" };

    const note = match[2].trim();
    if (!/\b(extra|finish|serve|serving|garnish|optional|plus)\b/i.test(note)) {
      return { name, note: "" };
    }

    return { name: match[1].trim(), note };
  }

  private cleanTag(value: unknown) {
    return this.cleanText(value)
      .toLowerCase()
      .replace(/[^a-z0-9_-]+/g, "_")
      .replace(/^_+|_+$/g, "");
  }

  private positiveIntOrUndefined(value: unknown) {
    return typeof value === "number" && Number.isInteger(value) && value > 0
      ? value
      : undefined;
  }

  private nonNegativeIntOrUndefined(value: unknown) {
    return typeof value === "number" && Number.isInteger(value) && value >= 0
      ? value
      : undefined;
  }
}
