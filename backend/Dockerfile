FROM node:22-bookworm-slim AS build

WORKDIR /app

RUN corepack enable

COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN apt-get update \
  && apt-get install -y --no-install-recommends python3 make g++ \
  && pnpm install --frozen-lockfile \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

COPY tsconfig.json tsconfig.build.json schema.sql ./
COPY src ./src
COPY scripts ./scripts
COPY seed ./seed
RUN pnpm build \
  && pnpm prune --prod

FROM node:22-bookworm-slim AS runtime

ENV NODE_ENV=production
WORKDIR /app

RUN corepack enable

COPY --from=build /app/package.json ./package.json
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/schema.sql ./schema.sql
COPY --from=build /app/scripts ./scripts
COPY --from=build /app/seed ./seed

EXPOSE 3000

CMD ["node", "dist/main.js"]
