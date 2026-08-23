import "reflect-metadata";

import { ValidationPipe } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { NestFactory } from "@nestjs/core";
import { AppModule } from "./app.module";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);
  const corsOrigin = config.get<string>("COOKBUK_CORS_ORIGIN", "*");

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

  const port = config.get<number>("COOKBUK_PORT", 3000);
  const host = config.get<string>("COOKBUK_HOST", "127.0.0.1");
  await app.listen(port, host);
}

void bootstrap();
