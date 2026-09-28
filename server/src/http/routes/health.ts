import { Hono } from "hono";

interface HealthRouterOptions {
  startedAtIso: string;
  ready?: () => Promise<boolean>;
}

export function createHealthRouter(options: HealthRouterOptions) {
  const router = new Hono();

  router.get("/", (c) => {
    return c.json(
      {
        status: "ok",
        service: "youki-sun-tracker-server",
        checks: {
          app: "ok",
        },
        startedAtIso: options.startedAtIso,
        checkedAtIso: new Date().toISOString(),
      },
      200,
    );
  });

  router.get("/live", (c) => {
    return c.json(
      {
        status: "ok",
        service: "youki-sun-tracker-server",
        check: "liveness",
        checkedAtIso: new Date().toISOString(),
      },
      200,
    );
  });

  router.get("/ready", async (c) => {
    const databaseReady = options.ready ? await options.ready() : true;
    return c.json(
      {
        status: databaseReady ? "ok" : "unavailable",
        service: "youki-sun-tracker-server",
        check: "readiness",
        checks: {
          routing: "ok",
          database: databaseReady ? "ok" : "unavailable",
        },
        startedAtIso: options.startedAtIso,
        checkedAtIso: new Date().toISOString(),
      },
      databaseReady ? 200 : 503,
    );
  });

  return router;
}
