import { createApp } from "./app";

const app = createApp();
const port = Number(process.env.PORT ?? 3000);

Bun.serve({
  hostname: "0.0.0.0",
  port,
  fetch: app.fetch,
});

console.log(`Server running at http://localhost:${port}`);
