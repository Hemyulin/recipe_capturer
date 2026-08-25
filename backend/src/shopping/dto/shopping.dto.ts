export class UpsertShoppingStoreDto {
  name?: string;
  isActive?: boolean;
}

export class UpsertShoppingItemDto {
  name?: string;
  storeId?: string | null;
}

export class CreateManualShoppingItemDto {
  name?: string;
  quantityLabel?: string;
  storeId?: string | null;
  rememberStore?: boolean;
}

export class UpdateManualShoppingItemDto {
  name?: string;
  quantityLabel?: string;
  storeId?: string | null;
  rememberStore?: boolean;
}
