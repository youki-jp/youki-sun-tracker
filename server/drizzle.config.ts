import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./src/infrastructure/auth/sqlite-schema.ts",
  out: "./drizzle",
  dialect: "sqlite",
});
