<h1 align="center">🌅 Youki — Sunrise & Sunset Tracking App</h1>

<p align="center">
  <img src="./public/app-image.jpg" width="300">
</p>

<p align="center">
  A clean, simple iOS app that displays daily sunrise & sunset times.  
  Built with <b>SwiftUI</b> + <b>TypeScript</b>.
</p>

---

## 📱 Overview

This app allows users to:

* Track daily **sunrise and sunset** times.
* View clean and minimal UI optimized for iOS.
* Use the app forever after a **one‑time purchase**.

The app fetches sunrise/sunset data from a public API and serves it through a lightweight TypeScript backend.

---

## 🏛️ Architecture

```
+---------------------+             +------------------------+
|      iOS App        |  <------>   |   TypeScript Server    |
|  (Swift / SwiftUI)  |             | (REST API Proxy Layer) |
+---------------------+             +------------------------+
            |                                 |
            |                                 v
            |                     External Sunrise/Sunset API
            |                        (e.g., sunrisesunset.io)
            v
     Client's Display
```

### **1. iOS App (SwiftUI)**

* Written fully in **Swift**.
* Handles UI, location permissions, and calling your TypeScript server.
* Displays sunrise/sunset results and additional info like day length.

### **2. TypeScript Server**

* Lightweight API layer built in Node.js / Express / Hono / Bun — your choice.

### **3. Sunrise/Sunset API**
[https://sunrisesunset.io/](https://sunrisesunset.io)

* Free and simple.
* Returns data in JSON format.

---

