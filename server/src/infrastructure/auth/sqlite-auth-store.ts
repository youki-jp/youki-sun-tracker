import { randomUUID } from "node:crypto";
import type { Database } from "bun:sqlite";
import type { Account, AuthStore, Tier } from "./auth-store";

type UserRow = { id: string; status: Account["status"]; apple_subject: string };
type IdRow = { id: string };

export class SqliteAuthStore implements AuthStore {
  constructor(private readonly db: Database, private readonly now = () => Date.now()) {}

  async ready(): Promise<boolean> {
    try { this.db.query("SELECT 1 FROM app_users LIMIT 1").get(); return true; }
    catch { return false; }
  }

  async saveChallenge(nonceHash: string): Promise<void> {
    const now = this.now();
    this.db.query("DELETE FROM auth_challenges WHERE expires_at < ?").run(now);
    this.db.query("INSERT INTO auth_challenges (nonce_hash, expires_at) VALUES (?, ?)")
      .run(nonceHash, now + 5 * 60_000);
  }

  async consumeChallenge(nonceHash: string): Promise<boolean> {
    const row = this.db.query("DELETE FROM auth_challenges WHERE nonce_hash = ? AND expires_at > ? RETURNING nonce_hash")
      .get(nonceHash, this.now());
    return row !== null;
  }

  async findOrCreateUser(appleSubject: string): Promise<Account> {
    this.db.query("INSERT INTO app_users (id, apple_subject, created_at) VALUES (?, ?, ?) ON CONFLICT (apple_subject) DO NOTHING")
      .run(randomUUID(), appleSubject, this.now());
    const row = this.db.query("SELECT id, status, apple_subject FROM app_users WHERE apple_subject = ?")
      .get(appleSubject) as UserRow;
    return this.accountFor(row);
  }

  async findLocalTestUser(email: string): Promise<Account | null> {
    const row = this.db.query("SELECT id, status, apple_subject FROM app_users WHERE apple_subject = ?")
      .get(`local-test:${email}`) as UserRow | null;
    return row ? this.accountFor(row) : null;
  }

  async isLocalTestUser(userId: string): Promise<boolean> {
    return this.db.query("SELECT 1 FROM app_users WHERE id = ? AND apple_subject LIKE 'local-test:%'")
      .get(userId) !== null;
  }

  async saveAppleRefreshToken(userId: string, ciphertext: string): Promise<void> {
    this.db.query("UPDATE app_users SET apple_refresh_ciphertext = ? WHERE id = ?").run(ciphertext, userId);
  }

  async appleRefreshToken(userId: string): Promise<string | null> {
    const row = this.db.query("SELECT apple_refresh_ciphertext AS token FROM app_users WHERE id = ?")
      .get(userId) as { token: string | null } | null;
    return row?.token ?? null;
  }

  async recentSession(userId: string, accessHash: string): Promise<boolean> {
    const now = this.now();
    return this.db.query(`SELECT 1 FROM user_sessions WHERE user_id = ? AND access_hash = ?
      AND revoked_at IS NULL AND access_expires_at > ? AND created_at > ? LIMIT 1`)
      .get(userId, accessHash, now, now - 10 * 60_000) !== null;
  }

  async createSession(userId: string, accessHash: string, refreshHash: string): Promise<void> {
    const now = this.now();
    this.db.query("DELETE FROM user_sessions WHERE refresh_expires_at < ?").run(now);
    this.db.query(`INSERT INTO user_sessions
      (id, user_id, access_hash, refresh_hash, access_expires_at, refresh_expires_at, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?)`)
      .run(randomUUID(), userId, accessHash, refreshHash, now + 15 * 60_000,
        now + 30 * 24 * 60 * 60_000, now);
  }

  async findByAccessHash(hash: string): Promise<Account | null> {
    const row = this.db.query(`SELECT u.id, u.status, u.apple_subject FROM user_sessions s
      JOIN app_users u ON u.id = s.user_id WHERE s.access_hash = ?
      AND s.revoked_at IS NULL AND s.access_expires_at > ?`)
      .get(hash, this.now()) as UserRow | null;
    return row ? this.accountFor(row) : null;
  }

  async rotateRefresh(oldHash: string, accessHash: string, refreshHash: string): Promise<Account | null> {
    const now = this.now();
    const row = this.db.query(`UPDATE user_sessions SET access_hash = ?, refresh_hash = ?,
      access_expires_at = ?, refresh_expires_at = ?
      WHERE refresh_hash = ? AND revoked_at IS NULL AND refresh_expires_at > ?
      AND EXISTS (SELECT 1 FROM app_users WHERE id = user_sessions.user_id AND status = 'active')
      RETURNING user_id AS id`)
      .get(accessHash, refreshHash, now + 15 * 60_000, now + 30 * 24 * 60 * 60_000,
        oldHash, now) as IdRow | null;
    if (!row) return null;
    const user = this.db.query("SELECT id, status, apple_subject FROM app_users WHERE id = ?")
      .get(row.id) as UserRow;
    return this.accountFor(user);
  }

  async revokeByAccessHash(hash: string): Promise<void> {
    this.db.query("UPDATE user_sessions SET revoked_at = ? WHERE access_hash = ? AND revoked_at IS NULL")
      .run(this.now(), hash);
  }

  async revokeByRefreshHash(hash: string): Promise<void> {
    this.db.query("UPDATE user_sessions SET revoked_at = ? WHERE refresh_hash = ? AND revoked_at IS NULL")
      .run(this.now(), hash);
  }

  async deleteUser(userId: string, accessHash: string): Promise<boolean> {
    const now = this.now();
    const row = this.db.query(`DELETE FROM app_users WHERE id = ? AND EXISTS (
      SELECT 1 FROM user_sessions WHERE user_id = app_users.id AND access_hash = ?
      AND revoked_at IS NULL AND access_expires_at > ? AND created_at > ?)
      RETURNING id`).get(userId, accessHash, now, now - 10 * 60_000);
    return row !== null;
  }

  async admit(userId: string, tier: Tier): Promise<{ allowed: boolean; retryAfter: number }> {
    const now = this.now();
    if (Math.random() < 0.01) {
      this.db.query("DELETE FROM request_counters WHERE window_start < ?").run(now - 90 * 24 * 60 * 60_000);
    }
    const minuteStart = Math.floor(now / 60_000) * 60_000;
    const dayStart = Math.floor(now / 86_400_000) * 86_400_000;
    const minuteLimit = tier === "pro" ? 60 : 20;
    const dayLimit = tier === "pro" ? 1500 : 300;
    // SQLite serializes the two writes, so a rejected minute request can undo its day increment.
    return this.db.transaction(() => {
      const day = this.incrementCounter(userId, "day", dayStart, dayLimit);
      if (!day) return { allowed: false, retryAfter: Math.ceil((dayStart + 86_400_000 - now) / 1000) };
      const minute = this.incrementCounter(userId, "minute", minuteStart, minuteLimit);
      if (!minute) {
        this.db.query(`UPDATE request_counters SET count = count - 1
          WHERE user_id = ? AND scope = 'day' AND window_start = ?`).run(userId, dayStart);
        return { allowed: false, retryAfter: Math.ceil((minuteStart + 60_000 - now) / 1000) };
      }
      return { allowed: true, retryAfter: 0 };
    }).immediate();
  }

  private incrementCounter(userId: string, scope: "minute" | "day", start: number, limit: number): boolean {
    return this.db.query(`INSERT INTO request_counters (user_id, scope, window_start, count)
      VALUES (?, ?, ?, 1) ON CONFLICT (user_id, scope, window_start)
      DO UPDATE SET count = count + 1 WHERE count < ? RETURNING count`)
      .get(userId, scope, start, limit) !== null;
  }

  private accountFor(row: UserRow): Account {
    const paid = this.db.query(`SELECT 1 FROM entitlements WHERE user_id = ?
      AND product_key = 'youki_pro_lifetime' AND status = 'active' LIMIT 1`).get(row.id);
    return { id: row.id, status: row.status, tier: paid ? "pro" : "free",
      ...(row.apple_subject.startsWith("local-test:") ? { email: row.apple_subject.slice(11) } : {}) };
  }
}
