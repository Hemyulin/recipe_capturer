import { Module } from "@nestjs/common";
import { DatabaseModule } from "../database/database.module";
import { ShoppingController } from "./shopping.controller";
import { ShoppingService } from "./shopping.service";

@Module({
  imports: [DatabaseModule],
  controllers: [ShoppingController],
  providers: [ShoppingService],
})
export class ShoppingModule {}
