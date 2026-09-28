import { createApp } from "./app";
import { SqliteAuthStore } from "./infrastructure/auth/sqlite-auth-store";
import { databasePath, openSqlite } from "./infrastructure/auth/sqlite-database";
import { AppleIdentityVerifier } from "./infrastructure/auth/apple-identity";
import { AppleTokenManager } from "./infrastructure/auth/apple-token-manager";
import { AuthService } from "./infrastructure/auth/auth-service";
import { LocalTestUsers } from "./infrastructure/auth/local-test-users";

const appleAudience = process.env.APPLE_CLIENT_ID;
const teamId = process.env.APPLE_TEAM_ID;
const keyId = process.env.APPLE_KEY_ID;
const privateKey = process.env.APPLE_PRIVATE_KEY;
const encryptionKey = process.env.APPLE_TOKEN_ENCRYPTION_KEY;
if (!appleAudience || !teamId || !keyId || !privateKey || !encryptionKey) {
  throw new Error("All APPLE_* settings are required.");
}
const db = openSqlite(databasePath());
const store = new SqliteAuthStore(db);
if (!await store.ready()) throw new Error("Auth schema missing; run bun run migrate before starting.");
const identity = new AppleIdentityVerifier(appleAudience);
const appleTokens = new AppleTokenManager(appleAudience, teamId, keyId, privateKey, encryptionKey, identity);
const localTestEnabled = process.env.ENABLE_LOCAL_TEST_USERS === "1" && process.env.NODE_ENV !== "production";
const localTestPassword = process.env.YOOKI_TEST_USER_PASSWORD;
if (localTestEnabled && !localTestPassword) throw new Error("YOOKI_TEST_USER_PASSWORD is required for local test users.");
const localTestUsers = localTestEnabled ? new LocalTestUsers(store, localTestPassword!) : undefined;
const app = createApp(new AuthService(store, identity, appleTokens, localTestUsers));
const port = Number(process.env.PORT ?? 3000);

Bun.serve({ hostname: localTestEnabled ? "127.0.0.1" : "0.0.0.0", port,
  maxRequestBodySize: 12 * 1024, fetch: app.fetch });
console.log(`Server running on port ${port}`);
