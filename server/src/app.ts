import { Hono } from "hono";
import { cors } from "hono/cors";
import { AppError } from "./application/errors";
import { createPredictSkyColorService } from "./infrastructure/factories/create-predict-sky-color-service";
import { createHealthRouter } from "./http/routes/health";
import { createSkyColorRouter } from "./http/routes/sky-color";

export function createApp() {
  const app = new Hono();
  const predictSkyColorService = createPredictSkyColorService();
  const startedAtIso = new Date().toISOString();

  // Browser-based prototypes call these endpoints directly from another origin.
  app.use("/api/*", cors());

  app.get("/", (c) => c.text("Hey Youki ☀️"));
  app.route(
    "/api/v1/health",
    createHealthRouter({
      startedAtIso,
    }),
  );
  app.route("/api/v1/sky-color", createSkyColorRouter(predictSkyColorService));
  app.onError((error, c) => {
    if (error instanceof AppError) {
      return c.json(
        {
          error: {
            code: error.code,
            message: error.message,
          },
        },
        error.statusCode,
      );
    }

    console.error(error);

    return c.json(
      {
        error: {
          code: "internal_server_error",
          message: "An unexpected error occurred.",
        },
      },
      500,
    );
  });

  return app;
}
