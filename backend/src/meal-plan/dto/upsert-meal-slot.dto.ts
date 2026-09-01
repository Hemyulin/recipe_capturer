import { IsArray, IsIn, IsOptional, IsString } from "class-validator";

export class UpsertMealSlotDto {
  @IsIn(["recipe", "leftovers", "away", "empty"])
  slotType!: "recipe" | "leftovers" | "away" | "empty";

  @IsOptional()
  @IsString()
  recipeId?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  extras?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  recipeExtraIds?: string[];
}
