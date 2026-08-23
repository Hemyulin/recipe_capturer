import { IsArray, IsString } from "class-validator";

export class UpdateMealExtrasDto {
  @IsArray()
  @IsString({ each: true })
  extras!: string[];
}
