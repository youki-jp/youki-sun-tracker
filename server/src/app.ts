import { Hono } from "hono";
import { AppError } from "./application/errors";
import { createPredictSkyColorService } from "./infrastructure/factories/create-predict-sky-color-service";
import { createSkyColorRouter } from "./http/routes/sky-color";

export function createApp() {
  const app = new Hono();
  const predictSkyColorService = createPredictSkyColorService();

  app.get("/", (c) => c.text("Hey Youki ☀️"));
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
