import { Hono } from "hono";

const app = new Hono();
const port = Number(process.env.PORT ?? 3000);

app.get("/", (c) => {
  return c.text("Hey Youki ☀️");
});

Bun.serve({
  port,
  fetch: app.fetch,
});

console.log(`Server running at http://localhost:${port}`);
