import { createCipheriv, createDecipheriv, createPrivateKey, randomBytes, sign } from "node:crypto";
import { AppError } from "../../application/errors";
import { AppleIdentityVerifier } from "./apple-identity";

export interface AppleTokens {
  exchange(code: string, nonce: string, expectedSubject: string): Promise<string | null>;
  encrypt(refreshToken: string): string;
  revoke(encryptedRefreshToken: string): Promise<void>;
}

export class AppleTokenManager implements AppleTokens {
  private readonly encryptionKey: Buffer;
  private readonly privateKey: ReturnType<typeof createPrivateKey>;

  constructor(private readonly clientId: string, private readonly teamId: string,
    private readonly keyId: string, privateKeyPem: string, encryptionKeyBase64: string,
    private readonly identity: AppleIdentityVerifier,
    private readonly fetcher: (url: string, init?: RequestInit) => Promise<Response> = fetch) {
    this.encryptionKey = Buffer.from(encryptionKeyBase64, "base64");
    if (this.encryptionKey.length !== 32) throw new Error("APPLE_TOKEN_ENCRYPTION_KEY must be 32 base64-encoded bytes.");
    this.privateKey = createPrivateKey(privateKeyPem.replace(/\\n/g, "\n"));
  }

  async exchange(code: string, nonce: string, expectedSubject: string): Promise<string | null> {
    if (code.length > 4096 || !code) throw new AppError("Invalid Apple authorization code.", "invalid_identity", 401);
    const body = new URLSearchParams({ client_id: this.clientId, client_secret: this.clientSecret(),
      code, grant_type: "authorization_code" });
    const response = await this.appleRequest("https://appleid.apple.com/auth/token", body);
    if (!response.ok) throw new AppError("Apple sign-in could not be verified.", "invalid_identity", 401);
    const payload = await response.json() as { id_token?: string; refresh_token?: string };
    if (!payload.id_token || await this.identity.verify(payload.id_token, nonce) !== expectedSubject) {
      throw new AppError("Apple sign-in could not be verified.", "invalid_identity", 401);
    }
    return payload.refresh_token ?? null;
  }

  encrypt(refreshToken: string): string {
    const iv = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.encryptionKey, iv);
    const ciphertext = Buffer.concat([cipher.update(refreshToken, "utf8"), cipher.final()]);
    return Buffer.concat([iv, cipher.getAuthTag(), ciphertext]).toString("base64");
  }

  async revoke(encryptedRefreshToken: string): Promise<void> {
    let refreshToken: string;
    try {
      const bytes = Buffer.from(encryptedRefreshToken, "base64");
      const decipher = createDecipheriv("aes-256-gcm", this.encryptionKey, bytes.subarray(0, 12));
      decipher.setAuthTag(bytes.subarray(12, 28));
      refreshToken = Buffer.concat([decipher.update(bytes.subarray(28)), decipher.final()]).toString("utf8");
    } catch { throw new AppError("Account deletion is temporarily unavailable.", "deletion_unavailable", 503); }
    const body = new URLSearchParams({ client_id: this.clientId, client_secret: this.clientSecret(),
      token: refreshToken, token_type_hint: "refresh_token" });
    const response = await this.appleRequest("https://appleid.apple.com/auth/revoke", body);
    if (!response.ok) throw new AppError("Account deletion is temporarily unavailable.", "deletion_unavailable", 503);
  }

  private clientSecret(): string {
    const encode = (value: object) => Buffer.from(JSON.stringify(value)).toString("base64url");
    const now = Math.floor(Date.now() / 1000);
    const unsigned = `${encode({ alg: "ES256", kid: this.keyId })}.${encode({ iss: this.teamId,
      iat: now, exp: now + 3600, aud: "https://appleid.apple.com", sub: this.clientId })}`;
    const signature = sign("sha256", Buffer.from(unsigned), { key: this.privateKey, dsaEncoding: "ieee-p1363" });
    return `${unsigned}.${signature.toString("base64url")}`;
  }

  private async appleRequest(url: string, body: URLSearchParams): Promise<Response> {
    try {
      return await this.fetcher(url, { method: "POST", body,
        headers: { "content-type": "application/x-www-form-urlencoded" }, signal: AbortSignal.timeout(5000) });
    } catch {
      throw new AppError("Apple identity service is temporarily unavailable.", "identity_unavailable", 503);
    }
  }
}
