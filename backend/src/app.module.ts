import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { DatabaseModule } from "./database/database.module";
import { HealthModule } from "./health/health.module";
import { MealPlanModule } from "./meal-plan/meal-plan.module";
import { RecipesModule } from "./recipes/recipes.module";

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: ".env",
    }),
    DatabaseModule,
    HealthModule,
    MealPlanModule,
    RecipesModule,
  ],
})
export class AppModule {}
