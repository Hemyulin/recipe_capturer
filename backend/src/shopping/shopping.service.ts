import { BadRequestException, Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { randomUUID } from "node:crypto";
import { DatabaseService } from "../database/database.service";
import {
  CreateManualShoppingItemDto,
  UpdateManualShoppingItemDto,
  UpsertShoppingItemDto,
  UpsertShoppingStoreDto,
} from "./dto/shopping.dto";

type StoreRow = {
  id: string;
  name: string;
  is_active: number;
};

type ShoppingItemRow = {
  id: string;
  name: string;
  normalized_name: string;
  store_id: string | null;
  store_name: string | null;
};

type ManualShoppingItemRow = {
  id: string;
  week_start: string;
  name: string;
  normalized_name: string;
  quantity_label: string | null;
  store_id: string | null;
  store_name: string | null;
};

@Injectable()
export class ShoppingService {
  constructor(
    private readonly database: DatabaseService,
    private readonly config: ConfigService,
  ) {}

  findStores() {
    const rows = this.database.db
      .prepare(
        `
        SELECT id, name, is_active
        FROM shopping_stores
        WHERE household_id = ?
        ORDER BY is_active DESC, lower(name) ASC
        `,
      )
      .all(this.householdId()) as StoreRow[];

    return rows.map(this.storeToApi);
  }

  createStore(input: UpsertShoppingStoreDto) {
    const name = this.normalizeText(input.name);
    if (!name) throw new BadRequestException("name is required");

    const id = randomUUID();
    this.database.db
      .prepare(
        `
        INSERT INTO shopping_stores (id, household_id, name, is_active)
        VALUES (?, ?, ?, 1)
        ON CONFLICT(household_id, name)
        DO UPDATE SET is_active = 1, updated_at = CURRENT_TIMESTAMP
        `,
      )
      .run(id, this.householdId(), name);

    return this.storeByName(name);
  }

  updateStore(id: string, input: UpsertShoppingStoreDto) {
    this.ensureStoreExists(id);
    const name = this.normalizeText(input.name);
    const isActive = input.isActive == null ? null : input.isActive ? 1 : 0;

    if (name) {
      this.database.db
        .prepare(
          `
          UPDATE shopping_stores
          SET name = ?, updated_at = CURRENT_TIMESTAMP
          WHERE household_id = ? AND id = ?
          `,
        )
        .run(name, this.householdId(), id);
    }

    if (isActive != null) {
      this.database.db
        .prepare(
          `
          UPDATE shopping_stores
          SET is_active = ?, updated_at = CURRENT_TIMESTAMP
          WHERE household_id = ? AND id = ?
          `,
        )
        .run(isActive, this.householdId(), id);
    }

    return this.storeById(id);
  }

  deactivateStore(id: string) {
    this.updateStore(id, { isActive: false });
  }

  findItems() {
    const rows = this.database.db
      .prepare(
        `
        SELECT
          item.id,
          item.name,
          item.normalized_name,
          item.store_id,
          store.name AS store_name
        FROM shopping_items item
        LEFT JOIN shopping_stores store ON store.id = item.store_id
        WHERE item.household_id = ?
        ORDER BY lower(item.name) ASC
        `,
      )
      .all(this.householdId()) as ShoppingItemRow[];

    return rows.map(this.itemToApi);
  }

  createItem(input: UpsertShoppingItemDto) {
    const name = this.normalizeText(input.name);
    if (!name) throw new BadRequestException("name is required");
    this.ensureNullableStore(input.storeId);

    const id = randomUUID();
    this.database.db
      .prepare(
        `
        INSERT INTO shopping_items (id, household_id, name, normalized_name, store_id)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(household_id, normalized_name)
        DO UPDATE SET
          name = excluded.name,
          store_id = excluded.store_id,
          updated_at = CURRENT_TIMESTAMP
        `,
      )
      .run(
        id,
        this.householdId(),
        name,
        this.normalizeKey(name),
        input.storeId ?? null,
      );

    return this.itemByNormalizedName(this.normalizeKey(name));
  }

  updateItem(id: string, input: UpsertShoppingItemDto) {
    this.ensureItemExists(id);
    this.ensureNullableStore(input.storeId);

    const existing = this.itemRowById(id);
    const name = this.normalizeText(input.name) || existing.name;
    const normalizedName = this.normalizeKey(name);
    const storeId = Object.prototype.hasOwnProperty.call(input, "storeId")
      ? (input.storeId ?? null)
      : existing.store_id;

    this.database.db
      .prepare(
        `
        UPDATE shopping_items
        SET name = ?, normalized_name = ?, store_id = ?, updated_at = CURRENT_TIMESTAMP
        WHERE household_id = ? AND id = ?
        `,
      )
      .run(name, normalizedName, storeId, this.householdId(), id);

    return this.itemById(id);
  }

  deleteItem(id: string) {
    this.database.db
      .prepare("DELETE FROM shopping_items WHERE household_id = ? AND id = ?")
      .run(this.householdId(), id);
  }

  findManualItems(weekStart?: string) {
    const normalizedWeekStart = this.normalizeDate(
      weekStart ?? this.startOfWeek(new Date()),
    );
    const rows = this.database.db
      .prepare(
        `
        SELECT
          item.id,
          item.week_start,
          item.name,
          item.normalized_name,
          item.quantity_label,
          item.store_id,
          store.name AS store_name
        FROM manual_shopping_items item
        LEFT JOIN shopping_stores store ON store.id = item.store_id
        WHERE item.household_id = ? AND item.week_start = ?
        ORDER BY lower(item.name) ASC
        `,
      )
      .all(this.householdId(), normalizedWeekStart) as ManualShoppingItemRow[];

    return rows.map(this.manualItemToApi);
  }

  createManualItem(weekStart: string, input: CreateManualShoppingItemDto) {
    const normalizedWeekStart = this.normalizeDate(weekStart);
    const name = this.normalizeText(input.name);
    if (!name) throw new BadRequestException("name is required");
    this.ensureNullableStore(input.storeId);

    const normalizedName = this.normalizeKey(name);
    const knownItem = this.itemRowByNormalizedName(normalizedName);
    const storeId = input.storeId ?? knownItem?.store_id ?? null;

    this.database.db
      .prepare(
        `
        INSERT INTO manual_shopping_items (
          id,
          household_id,
          week_start,
          name,
          normalized_name,
          quantity_label,
          store_id
        )
        VALUES (?, ?, ?, ?, ?, ?, ?)
        `,
      )
      .run(
        randomUUID(),
        this.householdId(),
        normalizedWeekStart,
        name,
        normalizedName,
        this.normalizeText(input.quantityLabel) || null,
        storeId,
      );

    if (input.rememberStore && storeId) {
      this.createItem({ name, storeId });
    }

    return this.findManualItems(normalizedWeekStart);
  }

  updateManualItem(id: string, input: UpdateManualShoppingItemDto) {
    const existing = this.manualItemRowById(id);
    if (!existing) throw new BadRequestException("manual item not found");
    this.ensureNullableStore(input.storeId);

    const name = this.normalizeText(input.name) || existing.name;
    const storeId = Object.prototype.hasOwnProperty.call(input, "storeId")
      ? (input.storeId ?? null)
      : existing.store_id;
    const quantityLabel = Object.prototype.hasOwnProperty.call(
      input,
      "quantityLabel",
    )
      ? this.normalizeText(input.quantityLabel) || null
      : existing.quantity_label;

    this.database.db
      .prepare(
        `
        UPDATE manual_shopping_items
        SET name = ?, normalized_name = ?, quantity_label = ?, store_id = ?
        WHERE household_id = ? AND id = ?
        `,
      )
      .run(
        name,
        this.normalizeKey(name),
        quantityLabel,
        storeId,
        this.householdId(),
        id,
      );

    if (input.rememberStore && storeId) {
      this.createItem({ name, storeId });
    }

    return this.findManualItems(existing.week_start);
  }

  deleteManualItem(id: string) {
    this.database.db
      .prepare(
        "DELETE FROM manual_shopping_items WHERE household_id = ? AND id = ?",
      )
      .run(this.householdId(), id);
  }

  private storeById(id: string) {
    const row = this.database.db
      .prepare(
        `
        SELECT id, name, is_active
        FROM shopping_stores
        WHERE household_id = ? AND id = ?
        `,
      )
      .get(this.householdId(), id) as StoreRow | undefined;
    if (!row) throw new BadRequestException("store not found");
    return this.storeToApi(row);
  }

  private storeByName(name: string) {
    const row = this.database.db
      .prepare(
        `
        SELECT id, name, is_active
        FROM shopping_stores
        WHERE household_id = ? AND name = ?
        `,
      )
      .get(this.householdId(), name) as StoreRow | undefined;
    if (!row) throw new BadRequestException("store not found");
    return this.storeToApi(row);
  }

  private itemById(id: string) {
    return this.itemToApi(this.itemRowById(id));
  }

  private itemByNormalizedName(normalizedName: string) {
    return this.itemToApi(this.itemRowByNormalizedName(normalizedName)!);
  }

  private itemRowById(id: string) {
    const row = this.database.db
      .prepare(
        `
        SELECT
          item.id,
          item.name,
          item.normalized_name,
          item.store_id,
          store.name AS store_name
        FROM shopping_items item
        LEFT JOIN shopping_stores store ON store.id = item.store_id
        WHERE item.household_id = ? AND item.id = ?
        `,
      )
      .get(this.householdId(), id) as ShoppingItemRow | undefined;
    if (!row) throw new BadRequestException("shopping item not found");
    return row;
  }

  private itemRowByNormalizedName(normalizedName: string) {
    return this.database.db
      .prepare(
        `
        SELECT
          item.id,
          item.name,
          item.normalized_name,
          item.store_id,
          store.name AS store_name
        FROM shopping_items item
        LEFT JOIN shopping_stores store ON store.id = item.store_id
        WHERE item.household_id = ? AND item.normalized_name = ?
        `,
      )
      .get(this.householdId(), normalizedName) as ShoppingItemRow | undefined;
  }

  private manualItemRowById(id: string) {
    return this.database.db
      .prepare(
        `
        SELECT
          item.id,
          item.week_start,
          item.name,
          item.normalized_name,
          item.quantity_label,
          item.store_id,
          store.name AS store_name
        FROM manual_shopping_items item
        LEFT JOIN shopping_stores store ON store.id = item.store_id
        WHERE item.household_id = ? AND item.id = ?
        `,
      )
      .get(this.householdId(), id) as ManualShoppingItemRow | undefined;
  }

  private ensureStoreExists(id: string) {
    this.storeById(id);
  }

  private ensureItemExists(id: string) {
    this.itemRowById(id);
  }

  private ensureNullableStore(storeId?: string | null) {
    if (!storeId) return;
    this.ensureStoreExists(storeId);
  }

  private storeToApi(row: StoreRow) {
    return {
      id: row.id,
      name: row.name,
      isActive: row.is_active === 1,
    };
  }

  private itemToApi(row: ShoppingItemRow) {
    return {
      id: row.id,
      name: row.name,
      normalizedName: row.normalized_name,
      storeId: row.store_id,
      storeName: row.store_name,
    };
  }

  private manualItemToApi(row: ManualShoppingItemRow) {
    return {
      id: row.id,
      weekStart: row.week_start,
      name: row.name,
      normalizedName: row.normalized_name,
      quantityLabel: row.quantity_label ?? "",
      storeId: row.store_id,
      storeName: row.store_name,
    };
  }

  private normalizeText(value?: string | null) {
    return (value ?? "").trim().replace(/\s+/g, " ");
  }

  private normalizeKey(value: string) {
    return value
      .toLocaleLowerCase("de-DE")
      .replace(/[^\p{L}\p{N}]+/gu, " ")
      .trim();
  }

  private normalizeDate(value: string) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value)) {
      throw new BadRequestException("Expected date as YYYY-MM-DD");
    }
    return value;
  }

  private startOfWeek(date: Date) {
    const normalized = new Date(
      Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
    );
    const day = normalized.getUTCDay() || 7;
    normalized.setUTCDate(normalized.getUTCDate() - day + 1);
    return normalized.toISOString().slice(0, 10);
  }

  private householdId() {
    return this.config.get<string>("COOKBUK_HOUSEHOLD_ID", "local-household");
  }
}
