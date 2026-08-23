import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
} from "@nestjs/common";
import { CreateRecipeDto } from "./dto/create-recipe.dto";
import { UpdateRecipeDto } from "./dto/update-recipe.dto";
import { RecipesService } from "./recipes.service";

@Controller("recipes")
export class RecipesController {
  constructor(private readonly recipesService: RecipesService) {}

  @Get()
  findAll() {
    return this.recipesService.findAll();
  }

  @Get(":id")
  findOne(@Param("id") id: string) {
    return this.recipesService.findOne(id);
  }

  @Post()
  create(@Body() body: CreateRecipeDto) {
    return this.recipesService.create(body);
  }

  @Patch(":id")
  update(@Param("id") id: string, @Body() body: UpdateRecipeDto) {
    return this.recipesService.update(id, body);
  }

  @Delete(":id")
  archive(@Param("id") id: string) {
    this.recipesService.archive(id);
    return { ok: true };
  }
}
