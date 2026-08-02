# iOS app

This directory contains a minimal SwiftUI client for the Youki server.

## Server URL configuration

The app reads `BACKEND_URL` from the Xcode scheme environment.

- Default: `http://localhost:3000`
- Fallback in code: `http://localhost:3000`

To point the app at DigitalOcean later, edit the `BACKEND_URL` environment variable in the shared `YoukiApp` scheme.

## What it does

The app makes a `GET /` request to the configured server and renders the plain-text response on screen.

