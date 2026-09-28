# Location forecast reuse plan

## Goal

Avoid forecast API calls when device GPS changes slightly but the user remains near the location used for the displayed forecast. Fetch a new forecast after meaningful movement, a local-day change, or the normal freshness interval.

## Implementation

1. Keep the location associated with the last successfully loaded timeline.
2. When Core Location returns a new fix, compare it with that forecast location using Core Location's geodesic distance. Treat fixes within 10 km as the same forecast area; this accommodates normal GPS drift and keeps Yokohama-area movement from triggering requests, while a trip into central Tokyo should cross the threshold.
3. For a same-area fix, retain the existing forecast and apply the existing 30-minute / local-day refresh rules. Do not clear the screen or issue the two forecast calls just because the coordinates moved within the threshold.
4. For a fix beyond the threshold, fetch the forecast for the new coordinates and replace the cached forecast only after loading it.
5. Keep the server's upstream Open-Meteo cache and bearer-token authentication unchanged. Cookie support is not part of this location cache.

## Scope and limits

The client cache remains in memory for the app session. The 10 km radius is a practical first threshold, not a city-boundary lookup; the displayed city name does not determine cache reuse. Existing time-based refresh remains responsible for forecast freshness.
