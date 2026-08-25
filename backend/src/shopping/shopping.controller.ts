import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
} from "@nestjs/common";
import {
  CreateManualShoppingItemDto,
  UpdateManualShoppingItemDto,
  UpsertShoppingItemDto,
  UpsertShoppingStoreDto,
} from "./dto/shopping.dto";
import { ShoppingService } from "./shopping.service";

@Controller("shopping")
export class ShoppingController {
  constructor(private readonly shoppingService: ShoppingService) {}

  @Get("stores")
  findStores() {
    return this.shoppingService.findStores();
  }

  @Post("stores")
  createStore(@Body() body: UpsertShoppingStoreDto) {
    return this.shoppingService.createStore(body);
  }

  @Patch("stores/:id")
  updateStore(@Param("id") id: string, @Body() body: UpsertShoppingStoreDto) {
    return this.shoppingService.updateStore(id, body);
  }

  @Delete("stores/:id")
  deactivateStore(@Param("id") id: string) {
    this.shoppingService.deactivateStore(id);
    return { ok: true };
  }

  @Get("items")
  findItems() {
    return this.shoppingService.findItems();
  }

  @Post("items")
  createItem(@Body() body: UpsertShoppingItemDto) {
    return this.shoppingService.createItem(body);
  }

  @Patch("items/:id")
  updateItem(@Param("id") id: string, @Body() body: UpsertShoppingItemDto) {
    return this.shoppingService.updateItem(id, body);
  }

  @Delete("items/:id")
  deleteItem(@Param("id") id: string) {
    this.shoppingService.deleteItem(id);
    return { ok: true };
  }

  @Get("manual-items")
  findManualItems(@Query("weekStart") weekStart?: string) {
    return this.shoppingService.findManualItems(weekStart);
  }

  @Post("manual-items/:weekStart")
  createManualItem(
    @Param("weekStart") weekStart: string,
    @Body() body: CreateManualShoppingItemDto,
  ) {
    return this.shoppingService.createManualItem(weekStart, body);
  }

  @Patch("manual-items/:id")
  updateManualItem(
    @Param("id") id: string,
    @Body() body: UpdateManualShoppingItemDto,
  ) {
    return this.shoppingService.updateManualItem(id, body);
  }

  @Delete("manual-items/:id")
  deleteManualItem(@Param("id") id: string) {
    this.shoppingService.deleteManualItem(id);
    return { ok: true };
  }
}
