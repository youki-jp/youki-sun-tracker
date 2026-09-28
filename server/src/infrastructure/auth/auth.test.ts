import { test, expect } from "bun:test";
import { createHash, generateKeyPairSync, randomBytes, verify } from "node:crypto";
import { createApp } from "../../app";
import { AppleIdentityVerifier } from "./apple-identity";
import { AuthService } from "./auth-service";
import { AppleTokenManager } from "./apple-token-manager";
import type { AuthStore, Account } from "./auth-store";

const digest = (v: string) => createHash("sha256").update(v).digest("hex");
const user: Account = { id: "test-user", tier: "free", status: "active" };
class Store implements AuthStore {
  async ready() { return true; }
  async saveAppleRefreshToken() {}
  async appleRefreshToken() { return "encrypted"; }
  async recentSession() { return true; }
  challenges = new Set<string>();
  access = new Map<string, Account>();
  refreshes = new Map<string, Account>();
  allowed = true;
  async saveChallenge(n: string) { this.challenges.add(n); }
  async consumeChallenge(n: string) { const ok = this.challenges.delete(n); return ok; }
  async findOrCreateUser() { return user; }
  async createSession(_id: string, a: string, r: string) { this.access.set(a, user); this.refreshes.set(r, user); }
  async findByAccessHash(a: string) { return this.access.get(a) ?? null; }
  async rotateRefresh(old: string, a: string, r: string) {
    const value = this.refreshes.get(old) ?? null; this.refreshes.delete(old);
    if (value) { this.access.set(a, value); this.refreshes.set(r, value); }
    return value;
  }
  async revokeByAccessHash(a: string) { this.access.delete(a); }
  async revokeByRefreshHash(r: string) { this.refreshes.delete(r); }
  async deleteUser() { return true; }
  async admit() { return { allowed: this.allowed, retryAfter: 30 }; }
}

async function fixture() {
  const keys = await crypto.subtle.generateKey({ name: "RSASSA-PKCS1-v1_5", modulusLength: 2048,
    publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"]);
  const jwk = { ...await crypto.subtle.exportKey("jwk", keys.publicKey), kid: "test", use: "sig", alg: "RS256" };
  const store = new Store();
  const auth = new AuthService(store, new AppleIdentityVerifier("jp.youki.YoukiApp", async () =>
    new Response(JSON.stringify({ keys: [jwk] }))), {
      exchange: async () => "apple-refresh",
      encrypt: () => "encrypted",
      revoke: async () => {},
    });
  async function identity(nonce: string, aud = "jp.youki.YoukiApp") {
    const b64 = (x: unknown) => Buffer.from(JSON.stringify(x)).toString("base64url");
    const now = Math.floor(Date.now() / 1000);
    const body = `${b64({ alg: "RS256", kid: "test" })}.${b64({ iss: "https://appleid.apple.com", aud,
      sub: "apple-user", nonce: digest(nonce), iat: now, exp: now + 300 })}`;
    const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", keys.privateKey, Buffer.from(body));
    return `${body}.${Buffer.from(signature).toString("base64url")}`;
  }
  return { store, auth, identity };
}
const req = (token?: string) => ({ method: "POST", headers: { "content-type": "application/json", ...(token ? { authorization: `Bearer ${token}` } : {}) }, body: "{}" });
const routes = ["/api/v1/sky-color/estimate", "/api/v1/sky-color/predictions", "/api/v1/sky-day/timeline"];

test("all forecast routes reject missing tokens before parsing", async () => {
  const { auth } = await fixture(); const app = createApp(auth);
  for (const route of routes) expect((await app.request(route, req())).status).toBe(401);
});
test("Apple audience, signature, and challenge replay are checked", async () => {
  const { auth, identity } = await fixture();
  const { nonce } = await auth.challenge();
  await expect(auth.signIn(await identity(nonce, "wrong"), "code", nonce)).rejects.toMatchObject({ statusCode: 401 });
  await expect(auth.signIn(await identity(nonce), "code", nonce)).rejects.toMatchObject({ statusCode: 401 });
  const next = await auth.challenge(); const signed = await identity(next.nonce);
  await expect(auth.signIn(signed.slice(0, -3) + "bad", "code", next.nonce)).rejects.toMatchObject({ statusCode: 401 });
});
test("opaque session refresh rotates and cannot replay", async () => {
  const { auth, identity } = await fixture(); const { nonce } = await auth.challenge();
  const first = await auth.signIn(await identity(nonce), "code", nonce);
  expect((await auth.authenticate(`Bearer ${first.accessToken}`)).id).toBe(user.id);
  const second = await auth.refresh(first.refreshToken);
  await expect(auth.refresh(first.refreshToken)).rejects.toMatchObject({ statusCode: 401 });
  expect((await auth.authenticate(`Bearer ${second.accessToken}`)).id).toBe(user.id);
});
test("all forecast aliases hit the account limiter", async () => {
  const { auth, store, identity } = await fixture(); const { nonce } = await auth.challenge();
  const issued = await auth.signIn(await identity(nonce), "code", nonce); store.allowed = false;
  const app = createApp(auth);
  for (const route of routes) {
    const response = await app.request(route, req(issued.accessToken));
    expect(response.status).toBe(429);
    expect(response.headers.get("retry-after")).toBe("30");
  }
});

test("Apple code exchange is signed and stored token can be revoked", async () => {
  const pair = generateKeyPairSync("ec", { namedCurve: "prime256v1" });
  const pem = pair.privateKey.export({ format: "pem", type: "pkcs8" }).toString();
  const calls: Array<{ url: string; body: URLSearchParams }> = [];
  const manager = new AppleTokenManager("jp.youki.YoukiApp", "TEAM", "KEY", pem,
    randomBytes(32).toString("base64"),
    { verify: async () => "apple-user" } as unknown as AppleIdentityVerifier,
    async (url, init) => {
      const body = init?.body as URLSearchParams;
      calls.push({ url: String(url), body });
      return url.toString().endsWith("/auth/token")
        ? new Response(JSON.stringify({ id_token: "verified-id", refresh_token: "secret-refresh" }))
        : new Response(null, { status: 200 });
    });
  const refresh = await manager.exchange("one-time-code", "nonce", "apple-user");
  expect(refresh).toBe("secret-refresh");
  const secret = calls[0].body.get("client_secret")!;
  const parts = secret.split(".");
  expect(verify("sha256", Buffer.from(`${parts[0]}.${parts[1]}`),
    { key: pair.publicKey, dsaEncoding: "ieee-p1363" }, Buffer.from(parts[2], "base64url"))).toBe(true);
  await manager.revoke(manager.encrypt(refresh!));
  expect(calls[1].url).toBe("https://appleid.apple.com/auth/revoke");
  expect(calls[1].body.get("token")).toBe("secret-refresh");
});
