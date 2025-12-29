# =========================
# 1. Dependencies
# =========================
FROM node:20-alpine AS deps

WORKDIR /app

# 必要なパッケージのみコピー
COPY package.json package-lock.json ./

RUN npm ci


# =========================
# 2. Build
# =========================
FROM node:20-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# standalone 出力を有効にする
# next.config.js で output: 'standalone' を設定している前提
RUN npm run build


# =========================
# 3. Production
# =========================
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=3000

# セキュリティ向上のため非 root ユーザー
RUN addgroup -g 1001 -S nodejs \
 && adduser -S nextjs -u 1001

# standalone に必要なファイルのみコピー
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static
COPY --from=builder /app/public ./public

USER nextjs

EXPOSE 3000

CMD ["node", "server.js"]

