import "reflect-metadata";

import { ValidationPipe } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { NestFactory } from "@nestjs/core";
import { NestExpressApplication } from "@nestjs/platform-express";
import { resolve } from "node:path";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  const config = app.get(ConfigService);
  const corsOrigin = config.get<string>("COOKBUK_CORS_ORIGIN", "*");
  const imageStoragePath = resolve(
    process.cwd(),
    config.get<string>("COOKBUK_IMAGE_STORAGE_PATH", "./data/images"),
  );

  app.enableCors({
    origin:
      corsOrigin === "*"
        ? true
        : corsOrigin.split(",").map((value) => value.trim()),
  });
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
    }),
  );
  app.useStaticAssets(imageStoragePath, { prefix: "/images/" });

  const port = config.get<number>("COOKBUK_PORT", 3000);
  const host = config.get<string>("COOKBUK_HOST", "127.0.0.1");
  await app.listen(port, host);
}

void bootstrap();
