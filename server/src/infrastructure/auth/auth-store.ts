export type Tier = "free" | "pro";
export interface Account {
  id: string;
  email?: string;
  tier: Tier;
  status: "active" | "suspended";
}

export interface AuthStore {
  ready(): Promise<boolean>;
  saveChallenge(nonceHash: string): Promise<void>;
  consumeChallenge(nonceHash: string): Promise<boolean>;
  findOrCreateUser(appleSubject: string): Promise<Account>;
  saveAppleRefreshToken(userId: string, ciphertext: string): Promise<void>;
  appleRefreshToken(userId: string): Promise<string | null>;
  recentSession(userId: string, accessHash: string): Promise<boolean>;
  createSession(userId: string, accessHash: string, refreshHash: string): Promise<void>;
  findByAccessHash(hash: string): Promise<Account | null>;
  rotateRefresh(oldHash: string, accessHash: string, refreshHash: string): Promise<Account | null>;
  revokeByAccessHash(hash: string): Promise<void>;
  revokeByRefreshHash(hash: string): Promise<void>;
  deleteUser(userId: string, accessHash: string): Promise<boolean>;
  admit(userId: string, tier: Tier): Promise<{ allowed: boolean; retryAfter: number }>;
}
