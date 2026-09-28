import { drizzle } from "drizzle-orm/bun-sqlite";
import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import { databasePath, openSqlite } from "../src/infrastructure/auth/sqlite-database";

const db = openSqlite(databasePath(), true);
try {
  migrate(drizzle({ client: db }), { migrationsFolder: "./drizzle" });
  console.log("SQLite auth schema is ready.");
} finally {
  db.close();
}
