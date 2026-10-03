export {};

if (!process.env.YOOKI_TEST_USER_PASSWORD) {
  throw new Error("Set YOOKI_TEST_USER_PASSWORD for the local test accounts.");
}
if (process.env.NODE_ENV === "production") throw new Error("Local test login is unavailable in production.");

process.env.NODE_ENV = "development";
process.env.AUTH_MODE = "temporary";
process.env.BIND_HOST = "127.0.0.1";

await import("./seed-test-users");
await import("../src/index");
