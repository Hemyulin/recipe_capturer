import { Module } from "@nestjs/common";
import { ConfigModule } from "@nestjs/config";
import { APP_GUARD } from "@nestjs/core";
import { SharedTokenGuard } from "./auth/shared-token.guard";
import { DatabaseModule } from "./database/database.module";
import { HealthModule } from "./health/health.module";
import { MealPlanModule } from "./meal-plan/meal-plan.module";
import { RecipesModule } from "./recipes/recipes.module";
import { ShoppingModule } from "./shopping/shopping.module";

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
    ShoppingModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: SharedTokenGuard }],
})
export class AppModule {}
