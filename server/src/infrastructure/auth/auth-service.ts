import { createHash, randomBytes } from "node:crypto";
import { AppError } from "../../application/errors";
import type { Account, AuthStore } from "./auth-store";
import { AppleIdentityVerifier } from "./apple-identity";
import type { AppleTokens } from "./apple-token-manager";
import type { LocalTestUsers } from "./local-test-users";

const hash = (value: string) => createHash("sha256").update(value).digest("hex");
const token = () => randomBytes(32).toString("base64url");

export class AuthService {
  constructor(private readonly store: AuthStore, private readonly apple?: AppleIdentityVerifier,
    private readonly appleTokens?: AppleTokens, private readonly localTestUsers?: LocalTestUsers) {}

  get appleSignInEnabled(): boolean { return this.apple !== undefined && this.appleTokens !== undefined; }
  get localTestLoginEnabled(): boolean { return this.localTestUsers !== undefined; }

  ready(): Promise<boolean> { return this.store.ready(); }

  async challenge(): Promise<{ nonce: string }> {
    if (!this.appleSignInEnabled) throw new AppError("Apple sign-in is disabled.", "not_found", 404);
    const nonce = token();
    await this.store.saveChallenge(hash(nonce));
    return { nonce };
  }

  async signIn(identityToken: string, authorizationCode: string, nonce: string) {
    if (!this.apple || !this.appleTokens) throw new AppError("Apple sign-in is disabled.", "not_found", 404);
    if (!await this.store.consumeChallenge(hash(nonce))) {
      throw new AppError("Sign-in challenge expired.", "invalid_challenge", 401);
    }
    const subject = await this.apple.verify(identityToken, nonce);
    if (!subject) throw new AppError("Apple sign-in could not be verified.", "invalid_identity", 401);
    const refreshTokenFromApple = await this.appleTokens.exchange(authorizationCode, nonce, subject);
    const account = await this.store.findOrCreateUser(subject);
    this.requireActive(account);
    if (refreshTokenFromApple) {
      await this.store.saveAppleRefreshToken(account.id, this.appleTokens.encrypt(refreshTokenFromApple));
    } else if (!await this.store.appleRefreshToken(account.id)) {
      throw new AppError("Apple sign-in did not provide a revocable session.", "invalid_identity", 401);
    }
    const accessToken = token(), refreshToken = token();
    await this.store.createSession(account.id, hash(accessToken), hash(refreshToken));
    return { accessToken, refreshToken, expiresIn: 900, account: publicAccount(account) };
  }

  async signInLocalTestUser(email: string, password: string) {
    if (!this.localTestUsers) throw new AppError("Route not found.", "not_found", 404);
    const account = await this.localTestUsers.authenticate(email, password);
    if (!account) throw new AppError("Invalid test account or password.", "invalid_credentials", 401);
    this.requireActive(account);
    const accessToken = token(), refreshToken = token();
    await this.store.createSession(account.id, hash(accessToken), hash(refreshToken));
    return { accessToken, refreshToken, expiresIn: 900, account: publicAccount(account) };
  }

  async authenticate(authorization: string | undefined): Promise<Account> {
    const match = /^Bearer ([A-Za-z0-9_-]{40,100})$/.exec(authorization ?? "");
    if (!match) throw new AppError("Sign in to continue.", "unauthorized", 401);
    const account = await this.store.findByAccessHash(hash(match[1]));
    if (!account) throw new AppError("Session expired. Sign in again.", "unauthorized", 401);
    this.requireActive(account);
    return account;
  }

  async refresh(refreshToken: string) {
    if (!/^[A-Za-z0-9_-]{40,100}$/.test(refreshToken)) {
      throw new AppError("Session expired. Sign in again.", "unauthorized", 401);
    }
    const accessToken = token(), replacement = token();
    const account = await this.store.rotateRefresh(hash(refreshToken), hash(accessToken), hash(replacement));
    if (!account) throw new AppError("Session expired. Sign in again.", "unauthorized", 401);
    return { accessToken, refreshToken: replacement, expiresIn: 900, account: publicAccount(account) };
  }

  async logout(authorization: string | undefined, refreshToken: string | undefined): Promise<void> {
    const match = /^Bearer ([A-Za-z0-9_-]{40,100})$/.exec(authorization ?? "");
    if (match) await this.store.revokeByAccessHash(hash(match[1]));
    if (refreshToken && /^[A-Za-z0-9_-]{40,100}$/.test(refreshToken)) {
      await this.store.revokeByRefreshHash(hash(refreshToken));
    }
  }

  async deleteAccount(account: Account, authorization: string | undefined): Promise<void> {
    const match = /^Bearer ([A-Za-z0-9_-]{40,100})$/.exec(authorization ?? "");
    if (!match) {
      throw new AppError("Sign in again before deleting your account.", "recent_sign_in_required", 403);
    }
    const accessHash = hash(match[1]);
    if (!await this.store.recentSession(account.id, accessHash)) {
      throw new AppError("Sign out and sign in again before deleting your account.", "recent_sign_in_required", 403);
    }
    const encryptedToken = await this.store.appleRefreshToken(account.id);
    if (encryptedToken) {
      if (!this.appleTokens) throw new AppError("Account deletion is temporarily unavailable.", "deletion_unavailable", 503);
      await this.appleTokens.revoke(encryptedToken);
    }
    else if (!await this.localTestUsers?.owns(account.id)) {
      throw new AppError("Account deletion is temporarily unavailable.", "deletion_unavailable", 503);
    }
    if (!await this.store.deleteUser(account.id, accessHash)) {
      throw new AppError("Sign out and sign in again before deleting your account.", "recent_sign_in_required", 403);
    }
  }

  async admit(account: Account): Promise<{ allowed: boolean; retryAfter: number }> {
    try { return await this.store.admit(account.id, account.tier); }
    catch { throw new AppError("Forecast service is temporarily unavailable.", "capacity_unavailable", 503); }
  }

  private requireActive(account: Account): void {
    if (account.status !== "active") throw new AppError("Account is unavailable.", "account_unavailable", 403);
  }
}

export function publicAccount(account: Account) {
  return { user: { id: account.id, ...(account.email ? { email: account.email } : {}) }, tier: account.tier,
    entitlements: account.tier === "pro" ? ["youki_pro_lifetime"] : [],
    capabilities: { liveForecast: true },
    limits: { forecastPerMinute: account.tier === "pro" ? 60 : 20,
      forecastPerDay: account.tier === "pro" ? 1500 : 300 } };
}
