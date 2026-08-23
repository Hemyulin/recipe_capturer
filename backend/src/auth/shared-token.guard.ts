import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { Reflector } from "@nestjs/core";
import { IS_PUBLIC_KEY } from "./public.decorator";

type RequestWithHeaders = {
  headers: Record<string, string | string[] | undefined>;
};

@Injectable()
export class SharedTokenGuard implements CanActivate {
  constructor(
    private readonly config: ConfigService,
    private readonly reflector: Reflector,
  ) {}

  canActivate(context: ExecutionContext) {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const configuredToken = this.config
      .get<string>("COOKBUK_SHARED_TOKEN", "")
      .trim();
    if (!configuredToken) return true;

    const request = context.switchToHttp().getRequest<RequestWithHeaders>();
    const providedToken = request.headers["x-cookbuk-token"];
    const token = Array.isArray(providedToken)
      ? providedToken[0]
      : providedToken;

    if (token === configuredToken) return true;

    throw new UnauthorizedException("CookBuk token is missing or invalid");
  }
}
