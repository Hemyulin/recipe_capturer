import { IsIn, IsOptional, IsString } from "class-validator";

export class UpsertMealSlotDto {
  @IsIn(["recipe", "leftovers", "empty"])
  slotType!: "recipe" | "leftovers" | "empty";

  @IsOptional()
  @IsString()
  recipeId?: string;
}
