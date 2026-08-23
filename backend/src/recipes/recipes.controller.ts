import {
  Body,
  BadRequestException,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  UploadedFile,
  UseInterceptors,
} from "@nestjs/common";
import { FileInterceptor } from "@nestjs/platform-express";
import { CreateRecipeDto } from "./dto/create-recipe.dto";
import { UpdateRecipeDto } from "./dto/update-recipe.dto";
import { RecipesService, UploadedRecipeImage } from "./recipes.service";

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

  @Post(":id/image")
  @UseInterceptors(
    FileInterceptor("image", {
      limits: { fileSize: 6 * 1024 * 1024 },
    }),
  )
  uploadImage(
    @Param("id") id: string,
    @UploadedFile() image?: UploadedRecipeImage,
  ) {
    if (!image) throw new BadRequestException("Image file is required");
    return this.recipesService.setMainImage(id, image);
  }

  @Delete(":id")
  archive(@Param("id") id: string) {
    this.recipesService.archive(id);
    return { ok: true };
  }
}
