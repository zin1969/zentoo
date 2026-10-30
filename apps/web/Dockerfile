# syntax=docker/dockerfile:1

# 本番用イメージ（next.config.ts の output: 'standalone' を使う）。設定は環境変数で受け取る。
#
#   docker build -t zentoo-web apps/web
#
# 必要な環境変数: RAILS_API_URL（Rails API の URL。例: http://api:3000）
# Cookie は production で secure になるため、HTTPS で配信すること。

ARG NODE_VERSION=22
FROM docker.io/library/node:$NODE_VERSION-slim AS base

WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1

FROM base AS deps

COPY package.json package-lock.json ./
RUN npm ci

FROM base AS build

COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM base AS runner

ENV NODE_ENV=production \
    PORT=3000 \
    HOSTNAME=0.0.0.0

# standalone 出力は、実行に必要な node_modules を含んだ server.js 一式
COPY --from=build --chown=node:node /app/.next/standalone ./
COPY --from=build --chown=node:node /app/.next/static ./.next/static
COPY --from=build --chown=node:node /app/public ./public

USER node

EXPOSE 3000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD node -e "fetch('http://localhost:' + (process.env.PORT || 3000) + '/login').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))"

CMD ["node", "server.js"]
