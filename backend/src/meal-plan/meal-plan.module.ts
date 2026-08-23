import { Module } from "@nestjs/common";
import { MealPlanController } from "./meal-plan.controller";
import { MealPlanService } from "./meal-plan.service";

@Module({
  controllers: [MealPlanController],
  providers: [MealPlanService],
})
export class MealPlanModule {}
