import { createHash, timingSafeEqual } from "node:crypto";
import type { Account } from "./auth-store";
import { SqliteAuthStore } from "./sqlite-auth-store";

export const localTestUsers = [
  { email: "paid-tier1@example.com", tier: "pro" },
  { email: "paid-tier2@example.com", tier: "pro" },
  { email: "free-tier1@example.com", tier: "free" },
  { email: "free-tier2@example.com", tier: "free" },
] as const;

export class LocalTestUsers {
  constructor(private readonly store: SqliteAuthStore, private readonly password: string) {}

  async authenticate(email: string, password: string): Promise<Account | null> {
    const normalized = email.trim().toLowerCase();
    const expected = createHash("sha256").update(this.password).digest();
    const actual = createHash("sha256").update(password).digest();
    if (!timingSafeEqual(expected, actual) || !localTestUsers.some((user) => user.email === normalized)) {
      return null;
    }
    return this.store.findLocalTestUser(normalized);
  }

  async owns(userId: string): Promise<boolean> {
    return this.store.isLocalTestUser(userId);
  }
}
