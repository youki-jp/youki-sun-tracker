import { createApp } from "./app";
import { SqliteAuthStore } from "./infrastructure/auth/sqlite-auth-store";
import { databasePath, openSqlite } from "./infrastructure/auth/sqlite-database";
import { AppleIdentityVerifier } from "./infrastructure/auth/apple-identity";
import { AppleTokenManager } from "./infrastructure/auth/apple-token-manager";
import { AuthService } from "./infrastructure/auth/auth-service";
import { LocalTestUsers } from "./infrastructure/auth/local-test-users";
import { authMode, testUserPassword } from "./infrastructure/auth/auth-config";

const mode = authMode();
const localTestEnabled = mode === "temporary" ||
  (process.env.ENABLE_LOCAL_TEST_USERS === "1" && process.env.NODE_ENV !== "production");
const localTestPassword = localTestEnabled ? testUserPassword() : undefined;
let identity: AppleIdentityVerifier | undefined;
let appleTokens: AppleTokenManager | undefined;
if (mode === "apple") {
  const appleAudience = process.env.APPLE_CLIENT_ID;
  const teamId = process.env.APPLE_TEAM_ID;
  const keyId = process.env.APPLE_KEY_ID;
  const privateKey = process.env.APPLE_PRIVATE_KEY;
  const encryptionKey = process.env.APPLE_TOKEN_ENCRYPTION_KEY;
  if (!appleAudience || !teamId || !keyId || !privateKey || !encryptionKey) {
    throw new Error("All APPLE_* settings are required.");
  }
  identity = new AppleIdentityVerifier(appleAudience);
  appleTokens = new AppleTokenManager(appleAudience, teamId, keyId, privateKey, encryptionKey, identity);
}
const db = openSqlite(databasePath());
const store = new SqliteAuthStore(db);
if (!await store.ready()) throw new Error("Auth schema missing; run bun run migrate before starting.");
const localTestUsers = localTestEnabled ? new LocalTestUsers(store, localTestPassword!) : undefined;
const app = createApp(new AuthService(store, identity, appleTokens, localTestUsers));
const port = Number(process.env.PORT ?? 3000);

Bun.serve({ hostname: process.env.BIND_HOST ??
  (localTestEnabled && process.env.NODE_ENV !== "production" ? "127.0.0.1" : "0.0.0.0"), port,
  maxRequestBodySize: 12 * 1024, fetch: app.fetch });
console.log(`Server running on port ${port}`);
