# Youki iOS app

This directory contains the SwiftUI prototype for Youki's sunrise and sunset color forecast experience.

## Run in Xcode

Open `YoukiApp/YoukiApp.xcodeproj`, select the `YoukiApp` scheme, choose an iOS Simulator or connected iPhone, and run. The project currently targets iOS 17 and newer.

## Prototype behavior

The current screen uses local sample data for Tokyo so the visual experience can be developed independently of the backend. It includes:

- Sunrise and sunset forecast presentation
- Expandable sky color analysis
- Forecast calendar with locked premium days
- Locations and subscription preview sheets
- Light and dark theme previews

The temporary sample data can be replaced when the API client is connected to the backend. `AppConfig.swift` and `ServerViewModel.swift` retain the initial backend connection seam and read `BACKEND_URL` from the Xcode scheme environment.

## Backend URL

The default backend URL is `http://localhost:3000`. To override it for future API wiring, add `BACKEND_URL` to the Xcode scheme environment.
