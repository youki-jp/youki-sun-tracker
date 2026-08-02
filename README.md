# Youki Sun Tracker

Clean starter project for the Youki backend.

## Current scope

The repository currently contains a minimal Bun + Hono server in `server/`.

## Hello world endpoint

Start the server:

```bash
cd server
bun install
bun run dev
```

Visit `http://localhost:3000` and the server will respond with:

```text
Hey Youki ☀️
```

## Next step

Once this baseline is in GitHub, we can build the DigitalOcean-ready deployment setup on top of it.

## DigitalOcean App Platform

If you deploy this repo from DigitalOcean App Platform, point the app's source directory to `server/`.

Use these commands:

```text
Build command: bun run build
Run command: bun run start
```
