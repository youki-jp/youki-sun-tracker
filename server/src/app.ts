import { Hono, type Context, type MiddlewareHandler } from "hono";
import { cors } from "hono/cors";
import { bodyLimit } from "hono/body-limit";
import type { ContentfulStatusCode } from "hono/utils/http-status";
import { AppError, ValidationError } from "./application/errors";
import { createPredictSkyColorService } from "./infrastructure/factories/create-predict-sky-color-service";
import { createSkyDayTimelineService } from "./infrastructure/factories/create-sky-day-timeline-service";
import { AuthService, publicAccount } from "./infrastructure/auth/auth-service";
import { createHealthRouter } from "./http/routes/health";
import { createSkyColorRouter } from "./http/routes/sky-color";
import { createSkyDayRouter } from "./http/routes/sky-day";

export function createApp(auth: AuthService) {
  const app = new Hono();
  const startedAtIso = new Date().toISOString();
  const origins = (process.env.CORS_ORIGINS ?? "").split(",").map((x) => x.trim()).filter(Boolean);
  if (origins.length) {
    app.use("/api/*", cors({ origin: (origin) => origins.includes(origin) ? origin : "" }));
  }
  app.use("/api/v1/*", async (c, next) => {
    c.header("X-Request-Id", crypto.randomUUID());
    await next();
  });
  const tooLarge = (c: Context) => c.json({ error: { code: "body_too_large", message: "Request body is too large." } }, 413);
  app.use("/api/v1/auth/*", bodyLimit({ maxSize: 12 * 1024, onError: tooLarge }));
  let authWindow = Date.now(), authCount = 0, authInFlight = 0;
  app.use("/api/v1/auth/*", async (c, next) => {
    if (c.req.method === "OPTIONS") return next();
    const now = Date.now();
    if (now - authWindow >= 60_000) { authWindow = now; authCount = 0; }
    if (authCount >= 600 || authInFlight >= 16) {
      c.header("Retry-After", "5");
      throw new AppError("Account service is busy.", "rate_limited", 429);
    }
    authCount++;
    authInFlight++;
    try { await next(); } finally { authInFlight--; }
  });
  for (const route of ["/api/v1/sky-color/*", "/api/v1/sky-day/*"]) {
    app.use(route, bodyLimit({ maxSize: 8 * 1024, onError: tooLarge }));
  }

  app.get("/", (c) => c.text("Youki"));
  app.route("/api/v1/health", createHealthRouter({ startedAtIso, ready: () => auth.ready() }));

  app.post("/api/v1/auth/challenge", async (c) => c.json(await auth.challenge(), 200));
  app.post("/api/v1/auth/apple", async (c) => {
    const body = await readObject(c.req.raw);
    return c.json(await auth.signIn(requiredString(body.identityToken, "identityToken", 8192),
      requiredString(body.authorizationCode, "authorizationCode", 4096),
      requiredString(body.nonce, "nonce", 128)), 200);
  });
  if (auth.localTestLoginEnabled) {
    app.post("/api/v1/auth/test-login", async (c) => {
      const body = await readObject(c.req.raw);
      return c.json(await auth.signInLocalTestUser(
        requiredString(body.email, "email", 254), requiredString(body.password, "password", 128)), 200);
    });
  }
  app.post("/api/v1/auth/refresh", async (c) => {
    const body = await readObject(c.req.raw);
    return c.json(await auth.refresh(requiredString(body.refreshToken, "refreshToken", 128)), 200);
  });
  app.post("/api/v1/auth/logout", async (c) => {
    const body = await readObject(c.req.raw);
    await auth.logout(c.req.header("authorization"),
      typeof body.refreshToken === "string" ? body.refreshToken : undefined);
    return c.body(null, 204);
  });

  app.get("/api/v1/me", async (c) => c.json(publicAccount(
    await auth.authenticate(c.req.header("authorization"))), 200));
  app.delete("/api/v1/me", async (c) => {
    const account = await auth.authenticate(c.req.header("authorization"));
    await auth.deleteAccount(account, c.req.header("authorization"));
    return c.body(null, 204);
  });

  let inFlight = 0;
  const forecastGuard: MiddlewareHandler = async (c, next) => {
    if (c.req.method === "OPTIONS") return next();
    const account = await auth.authenticate(c.req.header("authorization"));
    const limit = await auth.admit(account);
    if (!limit.allowed) {
      c.header("Retry-After", String(limit.retryAfter));
      throw new AppError("Too many forecast requests.", "rate_limited", 429);
    }
    if (inFlight >= 8) {
      c.header("Retry-After", "5");
      throw new AppError("Forecast service is busy.", "capacity_unavailable", 503);
    }
    inFlight++;
    try { await next(); } finally { inFlight--; }
  };
  app.use("/api/v1/sky-color/*", forecastGuard);
  app.use("/api/v1/sky-day/*", forecastGuard);
  app.route("/api/v1/sky-color", createSkyColorRouter(createPredictSkyColorService()));
  app.route("/api/v1/sky-day", createSkyDayRouter(createSkyDayTimelineService()));

  app.notFound((c) => c.json({ error: { code: "not_found", message: "Route not found." } }, 404));
  app.onError((error, c) => {
    const requestId = c.res.headers.get("X-Request-Id") ?? undefined;
    if (error instanceof AppError) {
      return c.json({ error: { code: error.code, message: error.message, requestId } }, error.statusCode as ContentfulStatusCode);
    }
    console.error("Request failed", { requestId, name: error instanceof Error ? error.name : "unknown" });
    return c.json({ error: { code: "internal_server_error", message: "An unexpected error occurred.", requestId } }, 500);
  });
  return app;
}

async function readObject(request: Request): Promise<Record<string, unknown>> {
  if (!request.headers.get("content-type")?.startsWith("application/json")) {
    throw new AppError("Use application/json.", "unsupported_media_type", 415);
  }
  const body: unknown = await request.json().catch(() => { throw new ValidationError("Request body must be valid JSON."); });
  if (!body || typeof body !== "object" || Array.isArray(body)) throw new ValidationError("Request body must be an object.");
  return body as Record<string, unknown>;
}

function requiredString(value: unknown, name: string, max: number): string {
  if (typeof value !== "string" || value.length < 1 || value.length > max) {
    throw new ValidationError(`${name} must be a non-empty string of at most ${max} characters.`);
  }
  return value;
}
