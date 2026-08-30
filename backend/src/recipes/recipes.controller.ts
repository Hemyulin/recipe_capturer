import {
  Body,
  BadRequestException,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
  Query,
  UploadedFile,
  UploadedFiles,
  UseInterceptors,
} from "@nestjs/common";
import { FileInterceptor, FilesInterceptor } from "@nestjs/platform-express";
import { CreateRecipeDto } from "./dto/create-recipe.dto";
import { UpdateRecipeDto } from "./dto/update-recipe.dto";
import { RecipesService, UploadedRecipeImage } from "./recipes.service";

@Controller("recipes")
export class RecipesController {
  constructor(private readonly recipesService: RecipesService) {}

  @Get()
  findAll(
    @Query("limit") limit?: string,
    @Query("offset") offset?: string,
    @Query("search") search?: string,
    @Query("favoritesOnly") favoritesOnly?: string,
    @Query("needsReviewOnly") needsReviewOnly?: string,
    @Query("season") season?: string,
    @Query("maxTotalTimeMinutes") maxTotalTimeMinutes?: string,
    @Query("tag") tag?: string,
  ) {
    if (
      limit != null ||
      offset != null ||
      search != null ||
      favoritesOnly != null ||
      needsReviewOnly != null ||
      season != null ||
      maxTotalTimeMinutes != null ||
      tag != null
    ) {
      return this.recipesService.findPage({
        limit,
        offset,
        search,
        favoritesOnly,
        needsReviewOnly,
        season,
        maxTotalTimeMinutes,
        tag,
      });
    }
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
  delete(@Param("id") id: string) {
    this.recipesService.delete(id);
    return { ok: true };
  }

  @Post("imports/photo")
  @UseInterceptors(
    FilesInterceptor("image", 5, {
      limits: { fileSize: 8 * 1024 * 1024, files: 5 },
    }),
  )
  importFromPhoto(@UploadedFiles() images?: UploadedRecipeImage[]) {
    if (!images?.length) {
      throw new BadRequestException("Image file is required");
    }
    return this.recipesService.importFromPhotos(images);
  }

  @Post("imports/polish")
  polishRecipe(@Body() body: CreateRecipeDto) {
    return this.recipesService.polishRecipeDraft(body);
  }

  @Post("imports/generated-image")
  generateRecipeImage(@Body() body: CreateRecipeDto) {
    return this.recipesService.generateRecipeImage(body);
  }
}
