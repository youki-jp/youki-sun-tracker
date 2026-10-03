import { randomUUID } from "node:crypto";
import { drizzle } from "drizzle-orm/bun-sqlite";
import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import { databasePath, openSqlite } from "../src/infrastructure/auth/sqlite-database";
import { localTestUsers } from "../src/infrastructure/auth/local-test-users";
import { authMode, testUserPassword } from "../src/infrastructure/auth/auth-config";

const mode = authMode();
if (process.argv.includes("--if-temporary") && mode !== "temporary") {
  console.log("Skipping test accounts; AUTH_MODE is not temporary.");
} else {
  if (process.env.NODE_ENV === "production") {
    if (mode !== "temporary") throw new Error("Test users require AUTH_MODE=temporary in production.");
    testUserPassword();
  }

  const db = openSqlite(databasePath(), true);
  try {
    migrate(drizzle({ client: db }), { migrationsFolder: "./drizzle" });
    db.transaction(() => {
      for (const user of localTestUsers) {
        const appleSubject = `local-test:${user.email}`;
        db.query(`INSERT INTO app_users (id, apple_subject, created_at) VALUES (?, ?, ?)
          ON CONFLICT (apple_subject) DO NOTHING`).run(randomUUID(), appleSubject, Date.now());
        const row = db.query("SELECT id FROM app_users WHERE apple_subject = ?")
          .get(appleSubject) as { id: string };
        if (user.tier === "pro") {
          db.query(`INSERT INTO entitlements (id, user_id, product_key, status, source, granted_at)
            SELECT ?, ?, 'youki_pro_lifetime', 'active', 'manual', ? WHERE NOT EXISTS (
              SELECT 1 FROM entitlements WHERE user_id = ? AND product_key = 'youki_pro_lifetime'
              AND status = 'active')`).run(randomUUID(), row.id, Date.now(), row.id);
        } else {
          db.query(`UPDATE entitlements SET status = 'revoked', revoked_at = ?
            WHERE user_id = ? AND product_key = 'youki_pro_lifetime' AND status = 'active'`)
            .run(Date.now(), row.id);
        }
      }
    }).immediate();
    console.log("Seeded two Free and two Pro test accounts.");
  } finally {
    db.close();
  }
}
