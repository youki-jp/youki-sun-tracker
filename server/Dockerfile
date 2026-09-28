FROM oven/bun:1.3.11

WORKDIR /app

COPY package.json bun.lock ./
RUN bun install --frozen-lockfile --production

COPY tsconfig.json ./
COPY src ./src
COPY drizzle ./drizzle
COPY scripts ./scripts

ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

CMD ["bun", "src/index.ts"]
