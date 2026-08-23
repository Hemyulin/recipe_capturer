import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Put,
  Query,
} from "@nestjs/common";
import { UpsertMealSlotDto } from "./dto/upsert-meal-slot.dto";
import { MealPlanService } from "./meal-plan.service";

@Controller("meal-plan")
export class MealPlanController {
  constructor(private readonly mealPlanService: MealPlanService) {}

  @Get()
  findRange(@Query("from") from?: string, @Query("to") to?: string) {
    return this.mealPlanService.findRange(from, to);
  }

  @Put(":date/:meal")
  upsert(
    @Param("date") date: string,
    @Param("meal") meal: string,
    @Body() body: UpsertMealSlotDto,
  ) {
    return this.mealPlanService.upsert(date, meal, body);
  }

  @Delete(":date/:meal")
  clear(@Param("date") date: string, @Param("meal") meal: string) {
    this.mealPlanService.clear(date, meal);
    return { ok: true };
  }
}
