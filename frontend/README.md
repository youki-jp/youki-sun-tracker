# Youki iOS app

This directory contains the SwiftUI prototype for Youki's sunrise and sunset color forecast experience.

## Run in Xcode

Open `YoukiApp/YoukiApp.xcodeproj`, select the `YoukiApp` scheme, choose an iOS Simulator or connected iPhone, and run. The project currently targets iOS 17 and newer.

## Current behavior

The current screen requests the device's location and calls the backend prediction API for the current sunrise and sunset. If permission is denied or the backend is unavailable, it keeps the local sample forecast visible and shows an error. It includes:

- Sunrise and sunset forecast presentation
- Expandable sky color analysis
- Forecast calendar with locked premium days
- Locations and subscription preview sheets
- Light and dark theme previews
- Live score, colors, event times, reasons, cloud cover, and UV data

The sample data remains as a fallback and for previews. `SkyColorAPI.swift`, `LocationManager.swift`, `ForecastMapper.swift`, and `ServerViewModel.swift` own the live integration.

## Backend URL

The default backend URL is `http://localhost:3000`. To override it, add `BACKEND_URL` to the Xcode scheme environment. This default works in the iOS Simulator; a physical device needs a reachable Mac/LAN URL instead of `localhost`.
