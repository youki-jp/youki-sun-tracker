import { generateKeyPairSync, randomBytes } from "node:crypto";

if (!process.env.YOOKI_TEST_USER_PASSWORD) {
  throw new Error("Set YOOKI_TEST_USER_PASSWORD for the local test accounts.");
}
if (process.env.NODE_ENV === "production") throw new Error("Local test login is unavailable in production.");

process.env.NODE_ENV = "development";
process.env.ENABLE_LOCAL_TEST_USERS = "1";
process.env.APPLE_CLIENT_ID ??= "jp.youki.YoukiApp";
process.env.APPLE_TEAM_ID ??= "LOCAL";
process.env.APPLE_KEY_ID ??= "LOCAL";
process.env.APPLE_PRIVATE_KEY ??= generateKeyPairSync("ec", { namedCurve: "prime256v1" })
  .privateKey.export({ type: "pkcs8", format: "pem" }).toString();
process.env.APPLE_TOKEN_ENCRYPTION_KEY ??= randomBytes(32).toString("base64");

await import("./seed-test-users");
await import("../src/index");
