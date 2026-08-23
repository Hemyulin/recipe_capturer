import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
  Put,
  Query,
} from "@nestjs/common";
import { UpdateMealExtrasDto } from "./dto/update-meal-extras.dto";
import { UpsertMealSlotDto } from "./dto/upsert-meal-slot.dto";
import { MealPlanService } from "./meal-plan.service";

@Controller("meal-plan")
export class MealPlanController {
  constructor(private readonly mealPlanService: MealPlanService) {}

  @Get()
  findRange(@Query("from") from?: string, @Query("to") to?: string) {
    return this.mealPlanService.findRange(from, to);
  }

  @Post("close-day/:date")
  closeDay(@Param("date") date: string) {
    return this.mealPlanService.closeDay(date);
  }

  @Put(":date/:meal")
  upsert(
    @Param("date") date: string,
    @Param("meal") meal: string,
    @Body() body: UpsertMealSlotDto,
  ) {
    return this.mealPlanService.upsert(date, meal, body);
  }

  @Put(":date/:meal/extras")
  updateExtras(
    @Param("date") date: string,
    @Param("meal") meal: string,
    @Body() body: UpdateMealExtrasDto,
  ) {
    return this.mealPlanService.updateExtras(date, meal, body);
  }

  @Delete(":date/:meal")
  clear(@Param("date") date: string, @Param("meal") meal: string) {
    this.mealPlanService.clear(date, meal);
    return { ok: true };
  }
}
