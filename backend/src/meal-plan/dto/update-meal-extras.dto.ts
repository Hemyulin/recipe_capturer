import { IsArray, IsOptional, IsString } from "class-validator";

export class UpdateMealExtrasDto {
  @IsArray()
  @IsString({ each: true })
  extras!: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  recipeExtraIds?: string[];
}
