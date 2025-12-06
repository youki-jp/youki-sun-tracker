🌅 Youki Hono Server — Sunrise/Sunset Backend (Bun + Hono)

A lightweight backend built with Bun and Hono, responsible for:
* Fetching sunrise and sunset data from an external API
* Validating one-time purchases via RevenueCat (server-to-server)
* Acting as a secure Backend-For-Frontend (BFF) for the iOS app

This server does not do real-time sun calculations — that heavy computation is done on-device in the iOS app.

🚀 Tech Stack

Runtime: Bun\
Server Framework: Hono\
Language: TypeScript\
Architecture: Backend-for-Frontend (BFF)\
Purpose: Secure sunrise/sunset fetching + payment validation

📁 Project Structure
/src
  /routes
    sunrise.ts
    purchase.ts
  index.ts
.env
bun.toml
README.md

✨ Features
1. Sunrise & Sunset Fetching

This API hits a third-party service (e.g., sunrisesunset.io) and returns clean, normalized JSON to the iOS app.

2. Server-Side Purchase Validation (RevenueCat)

Instead of validating purchases on-device:

The iOS app sends the RevenueCat App User ID or receipt token

The server verifies validity securely

The server returns isPaid: true | false

This prevents:

Jailbreak hacks

Fake local validation

User tampering

3. BFF Pattern

The server proxies all sensitive calls so the iOS app never directly hits external APIs.

🏗️ Example Endpoint: Sunrise/Sunset
import { Hono } from 'hono'
import { fetchSunTimes } from './services/sunriseService'

const app = new Hono()

app.get('/sun', async (c) => {
  const { lat, lng } = c.req.query()

  if (!lat || !lng) {
    return c.json({ error: 'lat and lng required' }, 400)
  }

  const data = await fetchSunTimes(lat, lng)
  return c.json(data)
})

export default app

🔐 Example Endpoint: Purchase Validation
app.get('/verify', async (c) => {
  const userId = c.req.query('userId')

  const res = await fetch(`https://api.revenuecat.com/v1/subscribers/${userId}`, {
    headers: { 'X-Platform': 'ios', 'Authorization': `Bearer ${process.env.RC_API_KEY}` }
  })

  const json = await res.json()

  return c.json({
    isPaid: json?.subscriber?.entitlements?.full_access?.is_active ?? false
  })
})

📦 Running Locally
1. Install Bun
curl -fsSL https://bun.sh/install | bash

2. Install dependencies
bun install

3. Run the server
bun run src/index.ts


Server will start at:

http://localhost:3000

🌅 Why No SSE or WebSockets?

You do not need SSE or real-time streams.

Sunrise/sunset data changes:

once per day

does not shift dynamically unless the user teleports

The iOS app handles:

gyroscope tracking

orientation reading

real-time sun angle math

A simple fetch every few minutes is more than enough.

🔍 Responsibilities: What This Server Does NOT Do

This server does not:

❌ Track gyroscope data
❌ Calculate real-time sun angles
❌ Handle heavy computation
❌ Stream real-time updates

Those belong on-device for performance, battery, and smooth UX.

🧭 Deployment Options

You can deploy the server easily on any Bun-friendly host:

Fly.io (best option)

Render

Railway

Bun Deploy

Docker container on EC2

Cloudflare Workers + Hono (if you remove Bun API usage)

Light traffic + tiny API → costs nearly zero.

💡 Summary

This Hono server is:

Lightweight

Fast

Cheap to run

Secure for purchase validation

Simple for fetching daily sun data

It provides the perfect backend for the Youki iOS app while keeping all real-time computation on the device.