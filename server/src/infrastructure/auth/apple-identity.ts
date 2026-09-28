import { createHash } from "node:crypto";

interface AppleClaims {
  iss: string;
  aud: string;
  sub: string;
  exp: number;
  iat: number;
  nonce: string;
}

interface AppleKey extends JsonWebKey { kid: string; kty: string; alg?: string; use?: string }

export class AppleIdentityVerifier {
  private keys: AppleKey[] = [];
  private fetchedAt = 0;

  constructor(private readonly audience: string,
    private readonly fetcher: (url: string, init?: RequestInit) => Promise<Response> = fetch) {}

  async verify(identityToken: string, rawNonce: string): Promise<string | null> {
    try {
      if (identityToken.length > 8192 || !/^[A-Za-z0-9_-]{32,128}$/.test(rawNonce)) return null;
      const parts = identityToken.split(".");
      if (parts.length !== 3) return null;
      const header = JSON.parse(Buffer.from(parts[0], "base64url").toString("utf8"));
      const claims = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8")) as AppleClaims;
      if (header.alg !== "RS256" || typeof header.kid !== "string" || header.kid.length > 128) return null;
      const now = Math.floor(Date.now() / 1000);
      const expectedNonce = createHash("sha256").update(rawNonce).digest("hex");
      if (claims.iss !== "https://appleid.apple.com" || claims.aud !== this.audience ||
          typeof claims.sub !== "string" || !claims.sub || claims.sub.length > 255 ||
          typeof claims.exp !== "number" || claims.exp <= now ||
          typeof claims.iat !== "number" || claims.iat > now + 60 ||
          claims.nonce !== expectedNonce) return null;
      let key = this.keys.find((item) => item.kid === header.kid);
      if (!key || Date.now() - this.fetchedAt > 3600_000) {
        await this.refreshKeys();
        key = this.keys.find((item) => item.kid === header.kid);
      }
      if (!key || key.kty !== "RSA" || (key.alg && key.alg !== "RS256") ||
          (key.use && key.use !== "sig")) return null;
      const publicKey = await crypto.subtle.importKey("jwk", key, { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["verify"]);
      const signed = new TextEncoder().encode(`${parts[0]}.${parts[1]}`);
      return await crypto.subtle.verify("RSASSA-PKCS1-v1_5", publicKey,
        Buffer.from(parts[2], "base64url"), signed) ? claims.sub : null;
    } catch {
      return null;
    }
  }

  private async refreshKeys(): Promise<void> {
    const response = await this.fetcher("https://appleid.apple.com/auth/keys", {
      signal: AbortSignal.timeout(3000),
      headers: { accept: "application/json" },
    });
    if (!response.ok) throw new Error("Apple signing keys unavailable");
    const body = await response.json() as { keys?: AppleKey[] };
    if (!Array.isArray(body.keys) || body.keys.length > 20) throw new Error("Invalid Apple signing keys");
    this.keys = body.keys;
    this.fetchedAt = Date.now();
  }
}
