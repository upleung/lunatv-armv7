# ---- 第 1 阶段：安装依赖（带缓存） ----
FROM node:20-alpine AS deps

RUN corepack enable && corepack prepare pnpm@10.14.0 --activate

WORKDIR /app

# 复制依赖清单
COPY package.json pnpm-lock.yaml ./

# 使用 pnpm store 缓存（极大加速依赖安装）
RUN pnpm install --frozen-lockfile

# ---- 第 2 阶段：构建项目（带缓存） ----
FROM node:20-alpine AS builder

RUN corepack enable && corepack prepare pnpm@10.14.0 --activate

WORKDIR /app

# 复制 node_modules（避免重复安装）
COPY --from=deps /app/node_modules ./node_modules

# 复制源代码
COPY . .

ENV DOCKER_ENV=true

# 使用 Babel 构建（ARMv7 兼容）
RUN pnpm run build

# ---- 第 3 阶段：运行时镜像 ----
FROM node:20-alpine AS runner

RUN addgroup -g 1001 -S nodejs && adduser -u 1001 -S nextjs -G nodejs

WORKDIR /app
ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3000
ENV DOCKER_ENV=true

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/scripts ./scripts
COPY --from=builder --chown=nextjs:nodejs /app/start.js ./start.js
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

CMD ["node", "start.js"]
