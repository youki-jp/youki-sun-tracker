import { Hono } from "hono";

interface HealthRouterOptions {
  startedAtIso: string;
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

  router.get("/ready", (c) => {
    return c.json(
      {
        status: "ok",
        service: "youki-sun-tracker-server",
        check: "readiness",
        checks: {
          routing: "ok",
        },
        startedAtIso: options.startedAtIso,
        checkedAtIso: new Date().toISOString(),
      },
      200,
    );
  });

  return router;
}
