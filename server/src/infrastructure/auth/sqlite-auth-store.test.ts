import { afterEach, expect, test } from "bun:test";
import { copyFileSync, mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { drizzle } from "drizzle-orm/bun-sqlite";
import { migrate } from "drizzle-orm/bun-sqlite/migrator";
import { createApp } from "../../app";
import { AppleIdentityVerifier } from "./apple-identity";
import { AuthService } from "./auth-service";
import { openSqlite } from "./sqlite-database";
import { SqliteAuthStore } from "./sqlite-auth-store";
import { LocalTestUsers, localTestUsers } from "./local-test-users";

const temporaryDirectories: string[] = [];
afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) rmSync(directory, { recursive: true, force: true });
});

function fixture() {
  const directory = mkdtempSync(join(tmpdir(), "youki-auth-"));
  temporaryDirectories.push(directory);
  const databaseFile = join(directory, "auth.sqlite");
  const db = openSqlite(databaseFile, true);
  const migrationsFolder = join(import.meta.dir, "../../../drizzle");
  migrate(drizzle({ client: db }), { migrationsFolder });
  migrate(drizzle({ client: db }), { migrationsFolder });
  let clock = Date.UTC(2026, 8, 28, 12);
  const store = new SqliteAuthStore(db, () => clock);
  return { db, store, directory, databaseFile, setClock: (value: number) => { clock = value; } };
}

test("migrations, challenge replay, sessions, and refresh rotation use real SQLite", async () => {
  const { db, store, setClock } = fixture();
  try {
    expect(await store.ready()).toBe(true);
    await store.saveChallenge("nonce");
    expect(await store.consumeChallenge("nonce")).toBe(true);
    expect(await store.consumeChallenge("nonce")).toBe(false);
    await store.saveChallenge("expired");
    setClock(Date.UTC(2026, 8, 28, 12, 6));
    expect(await store.consumeChallenge("expired")).toBe(false);

    const account = await store.findOrCreateUser("apple-1");
    expect(account.tier).toBe("free");
    expect((await store.findOrCreateUser("apple-1")).id).toBe(account.id);
    await store.saveAppleRefreshToken(account.id, "encrypted");
    expect(await store.appleRefreshToken(account.id)).toBe("encrypted");
    await store.createSession(account.id, "access-1", "refresh-1");
    expect(await store.recentSession(account.id, "access-1")).toBe(true);
    expect((await store.findByAccessHash("access-1"))?.id).toBe(account.id);
    expect((await store.rotateRefresh("refresh-1", "access-2", "refresh-2"))?.id).toBe(account.id);
    expect(await store.rotateRefresh("refresh-1", "replay", "replay")).toBeNull();
    expect(await store.findByAccessHash("access-1")).toBeNull();
    await store.revokeByRefreshHash("refresh-2");
    expect(await store.findByAccessHash("access-2")).toBeNull();
  } finally { db.close(); }
});

test("entitlement changes tier and recent account deletion cascades records", async () => {
  const { db, store, setClock } = fixture();
  try {
    const account = await store.findOrCreateUser("apple-2");
    db.query(`INSERT INTO entitlements
      (id, user_id, product_key, status, source, granted_at)
      VALUES (?, ?, 'youki_pro_lifetime', 'active', 'manual', ?)`)
      .run(crypto.randomUUID(), account.id, Date.UTC(2026, 8, 28, 12));
    expect((await store.findOrCreateUser("apple-2")).tier).toBe("pro");
    await store.createSession(account.id, "access", "refresh");
    expect(await store.deleteUser(account.id, "wrong")).toBe(false);
    setClock(Date.UTC(2026, 8, 28, 12, 11));
    expect(await store.deleteUser(account.id, "access")).toBe(false);
    await store.createSession(account.id, "new-access", "new-refresh");
    expect(await store.deleteUser(account.id, "new-access")).toBe(true);
    expect(await store.findByAccessHash("new-access")).toBeNull();
    expect(db.query("SELECT count(*) AS n FROM entitlements").get()).toEqual({ n: 0 });
    expect(db.query("SELECT count(*) AS n FROM user_sessions").get()).toEqual({ n: 0 });
  } finally { db.close(); }
});

test("quota writes are atomic and rejected requests do not spend the day budget", async () => {
  const { db, store, setClock } = fixture();
  try {
    const account = await store.findOrCreateUser("apple-3");
    for (let i = 0; i < 20; i++) expect((await store.admit(account.id, "free")).allowed).toBe(true);
    expect(await store.admit(account.id, "free")).toMatchObject({ allowed: false, retryAfter: 60 });
    expect(db.query("SELECT count AS n FROM request_counters WHERE scope = 'day'").get()).toEqual({ n: 20 });
    setClock(Date.UTC(2026, 8, 28, 12, 1));
    expect((await store.admit(account.id, "free")).allowed).toBe(true);
    db.query("UPDATE request_counters SET count = 300 WHERE scope = 'day'").run();
    expect((await store.admit(account.id, "free")).allowed).toBe(false);
    expect(db.query("SELECT count AS n FROM request_counters WHERE scope = 'minute' ORDER BY window_start DESC LIMIT 1").get())
      .toEqual({ n: 1 });
  } finally { db.close(); }
});

test("HTTP sign-in, account, refresh, and logout routes persist in SQLite", async () => {
  const { db, store } = fixture();
  try {
    const auth = new AuthService(store,
      { verify: async () => "apple-http" } as unknown as AppleIdentityVerifier,
      { exchange: async () => "apple-refresh", encrypt: () => "encrypted", revoke: async () => {} });
    const app = createApp(auth);
    const challenge = await app.request("/api/v1/auth/challenge", { method: "POST" });
    expect(challenge.status).toBe(200);
    const { nonce } = await challenge.json() as { nonce: string };
    const signIn = await app.request("/api/v1/auth/apple", { method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ identityToken: "signed", authorizationCode: "code", nonce }) });
    expect(signIn.status).toBe(200);
    const first = await signIn.json() as { accessToken: string; refreshToken: string };
    const me = await app.request("/api/v1/me", { headers: { authorization: `Bearer ${first.accessToken}` } });
    expect(me.status).toBe(200);
    expect((await me.json() as { tier: string }).tier).toBe("free");
    const refresh = await app.request("/api/v1/auth/refresh", { method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ refreshToken: first.refreshToken }) });
    expect(refresh.status).toBe(200);
    const second = await refresh.json() as { accessToken: string; refreshToken: string };
    const replay = await app.request("/api/v1/auth/refresh", { method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ refreshToken: first.refreshToken }) });
    expect(replay.status).toBe(401);
    const logout = await app.request("/api/v1/auth/logout", { method: "POST",
      headers: { "content-type": "application/json", authorization: `Bearer ${second.accessToken}` },
      body: JSON.stringify({ refreshToken: second.refreshToken }) });
    expect(logout.status).toBe(204);
    expect((await app.request("/api/v1/me", { headers: { authorization: `Bearer ${second.accessToken}` } })).status).toBe(401);
  } finally { db.close(); }
});

test("local test users are seeded idempotently and use normal tiered sessions", async () => {
  const { db, store, databaseFile } = fixture();
  try {
    const serverRoot = join(import.meta.dir, "../../..");
    for (let run = 0; run < 2; run++) {
      const seed = Bun.spawn([process.execPath, "scripts/seed-test-users.ts"], {
        cwd: serverRoot, env: { ...process.env, NODE_ENV: "development", SQLITE_PATH: databaseFile },
        stdout: "pipe", stderr: "pipe",
      });
      expect(await seed.exited).toBe(0);
    }
    expect(db.query("SELECT count(*) AS n FROM app_users WHERE apple_subject LIKE 'local-test:%'").get())
      .toEqual({ n: 4 });
    expect(db.query("SELECT count(*) AS n FROM entitlements WHERE status = 'active'").get())
      .toEqual({ n: 2 });

    const auth = new AuthService(store,
      { verify: async () => null } as unknown as AppleIdentityVerifier,
      { exchange: async () => null, encrypt: () => "", revoke: async () => {} },
      new LocalTestUsers(store, "test-password"));
    const app = createApp(auth);
    for (const user of localTestUsers) {
      const response = await app.request("/api/v1/auth/test-login", { method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ email: user.email, password: "test-password" }) });
      expect(response.status).toBe(200);
      const issued = await response.json() as { accessToken: string; refreshToken: string;
        account: { tier: string; user: { email: string } } };
      expect(issued.account.tier).toBe(user.tier);
      expect(issued.account.user.email).toBe(user.email);
      const me = await app.request("/api/v1/me", { headers: { authorization: `Bearer ${issued.accessToken}` } });
      expect((await me.json() as { tier: string }).tier).toBe(user.tier);
      const refreshed = await auth.refresh(issued.refreshToken);
      expect(refreshed.account.tier).toBe(user.tier);
    }
    const wrong = await app.request("/api/v1/auth/test-login", { method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ email: "paid-tier1@example.com", password: "wrong" }) });
    expect(wrong.status).toBe(401);
    const disabled = createApp(new AuthService(store,
      { verify: async () => null } as unknown as AppleIdentityVerifier,
      { exchange: async () => null, encrypt: () => "", revoke: async () => {} }));
    expect((await disabled.request("/api/v1/auth/test-login", { method: "POST" })).status).toBe(404);
  } finally { db.close(); }
});

test("backup command captures live records and restores a usable database", async () => {
  const { db, store, directory, databaseFile } = fixture();
  try {
    const account = await store.findOrCreateUser("apple-backup");
    await store.createSession(account.id, "saved-access", "saved-refresh");
    const backupPath = join(directory, "backup.sqlite");
    const serverRoot = join(import.meta.dir, "../../..");
    const backup = Bun.spawn([process.execPath, "scripts/backup.ts", backupPath], {
      cwd: serverRoot, env: { ...process.env, SQLITE_PATH: databaseFile }, stdout: "pipe", stderr: "pipe",
    });
    expect(await backup.exited).toBe(0);
    const restoredPath = join(directory, "restored.sqlite");
    copyFileSync(backupPath, restoredPath);
    const restored = openSqlite(restoredPath);
    try {
      const restoredStore = new SqliteAuthStore(restored);
      expect((await restoredStore.findOrCreateUser("apple-backup")).id).toBe(account.id);
      expect(restored.query("SELECT count(*) AS n FROM user_sessions").get()).toEqual({ n: 1 });
    } finally { restored.close(); }
  } finally { db.close(); }
});
