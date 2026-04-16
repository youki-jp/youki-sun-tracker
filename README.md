<h1 align="center">🌅 Youki — Sunrise & Sunset Tracking App</h1>

<p align="center">
  A clean, simple iOS app that displays daily sunrise & sunset times.  
  Built with <b>SwiftUI</b> + <b>TypeScript</b>.
</p>
<p align="center">
  <img src="./public/app-image.jpg" width="300">
</p>


## 📱 Overview

This app allows users to:

* Track daily **sunrise and sunset** times.
* View clean and minimal UI optimized for iOS.
* Use the app forever after a **one‑time purchase**.

The app fetches sunrise/sunset data from a public API and serves it through a lightweight TypeScript backend.

## Local Backend

Swift/iOS does not natively load `.env` files at runtime the way a JavaScript app does.
For this project:

* the Bun backend can use `.env`
* the iOS app reads `BACKEND_URL` from the Xcode run environment when you launch from Xcode
* if no environment variable is set, the app falls back to `http://localhost:3000/sun`, which is useful for the iOS Simulator

Create a local `.env` from `.env.example` for your own machine-specific values.

You can run the backend in Docker:

```bash
docker compose up --build
```

This publishes the Bun server on `http://127.0.0.1:3000/sun`.

Use these frontend URLs depending on where the app is running:

```text
iOS Simulator: http://127.0.0.1:3000/sun
Real iPhone on same Wi-Fi: http://YOUR_MAC_LAN_IP:3000/sun
```

`host.docker.internal` is useful from inside a Docker container when that container needs to call a service running on your Mac. It is usually not the right hostname for the iPhone app itself.

For a real iPhone, set `BACKEND_URL` in your local Xcode scheme to something like:

```text
http://YOUR_MAC_LAN_IP:3000/sun
```

Do not commit your personal LAN IP to git.


## 🏛️ Architecture

<p align="center">
  <img src="./public/architecture.png">
</p>

### **1. iOS App (SwiftUI)**

* Written fully in **Swift**.
* Handles UI, location permissions, and calling your server for sun data, and accessing Gyroscope to calculate sun location.
* Displays sunrise/sunset results and additional info like day length.

### **2. Hono Server**
* Lightweight API layer built in Bun as the runtime, and Hono as the server library. 
https://hono.dev/

### **3. Sunrise/Sunset API**
* Shoutout to the maintainer of this api. \
[https://sunrisesunset.io/](https://sunrisesunset.io)

### **4. Payment**
* RevenueCat to handle user's payment info check.\
https://www.revenuecat.com/docs/
