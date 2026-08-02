import { Hono } from "hono";

const app = new Hono();
const port = Number(process.env.PORT ?? 3000);

app.get("/", (c) => {
  return c.text("Hey Youki ☀️");
});

Bun.serve({
  hostname: "0.0.0.0",
  port,
  fetch: app.fetch,
});

console.log(`Server running at http://localhost:${port}`);
