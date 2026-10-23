![Skua](assets/skua-banner.png)

# skua

Your fowl-weather friend. A faster, sharper take on weather, with a bird that
reads your day. Free, with no ads and no paid tier.

skua wraps real forecast data in a clean, modern client and an optional AI voice
with attitude. It leads on the web and grows to native clients.

## Why

Weather data is nearly free at small scale. The premium weather apps charge for
polish and personality, and both are reproducible. skua pairs a clean client
with a context-aware voice and a plugin model, and gives all of it away under
Apache 2.0.

## Architecture

The backend is a small Go HTTP service. It fans out to several weather sources,
normalizes each into one forecast shape, caches every response aggressively so
data costs stay near zero, and serves compact JSON to the clients. Every source
sits behind a single-method provider interface, so adding or swapping a source
does not touch the handlers.

Clients are a web app and a native iOS app. Both talk only to the backend, never
to the upstream sources directly.

## Data sources

One normalized forecast shape sits over many providers. Each domain has its own
provider so a source can be swapped without touching the rest.

| Domain                                        | Source                                                          |
| --------------------------------------------- | --------------------------------------------------------------- |
| Forecast, current and hourly and daily, moon  | Open-Meteo by default, Apple WeatherKit when credentials are set |
| Air quality                                   | Open-Meteo air quality                                          |
| Marine and waves                              | Open-Meteo marine                                               |
| Lightning potential                           | Open-Meteo                                                      |
| Aurora                                         | NOAA Space Weather Prediction Center                            |
| Radar tiles                                   | RainViewer                                                      |
| Severe alerts                                 | National Weather Service, api.weather.gov                       |
| Tides                                         | NOAA Tides and Currents                                         |
| Place search and geocoding                    | Open-Meteo geocoding, called by the client                      |
| Voice                                         | Claude when an API key is set, built-in line bank otherwise      |

The forecast source is chosen at startup. When the WeatherKit credentials are
present and the signing key parses, WeatherKit is used. Otherwise the service
falls back to Open-Meteo and logs the choice.

## Features

- Daily briefing: one sharp paragraph that fuses the forecast, alerts, and the
  shape of the day into what matters before you walk out the door.
- Contextual voice: a mascot that reacts to real conditions, alerts, and what
  changed since the last look, at a maturity level you pick.
- Minute rain: nowcasting for when rain starts and stops where you stand.
- Severe alerts: official warnings in plain language the moment they post.
- Overlays: air quality, marine, aurora, tides, lightning, and radar, added per
  location as you want them.
- Many places: save every location that matters and glance across them at once.
- Flight plan: a personal read of the day and the week ahead, tied to conditions.

## HTTP API

Every endpoint is a GET and returns compact JSON. Location endpoints take `lat`
and `lon` query parameters.

| Method and path   | Purpose                                   |
| ----------------- | ----------------------------------------- |
| `GET /healthz`    | Liveness check                            |
| `GET /forecast`   | Normalized current, hourly, daily, moon   |
| `GET /voice`      | The skua's take, with `level` and `units` |
| `GET /airquality` | Air quality index and pollutants          |
| `GET /marine`     | Waves and marine conditions               |
| `GET /aurora`     | Aurora visibility                         |
| `GET /radar`      | Radar tile host and frames                |
| `GET /alerts`     | Active severe weather alerts              |
| `GET /tides`      | Tide predictions                          |
| `GET /lightning`  | Lightning potential                       |

## Running locally

Build and start the service. It listens on `:8080` by default.

```sh
go build -o skua .
./skua
```

Configuration is read from the environment.

| Variable                     | Purpose                                           |
| ---------------------------- | ------------------------------------------------- |
| `SKUA_ADDR`                  | Listen address, defaults to `:8080`               |
| `ANTHROPIC_API_KEY`          | Enables the Claude voice, line bank used if unset |
| `SKUA_WEATHERKIT_TEAM_ID`    | Apple Developer team identifier                   |
| `SKUA_WEATHERKIT_SERVICE_ID` | Registered WeatherKit service identifier          |
| `SKUA_WEATHERKIT_KEY_ID`     | Signing key identifier                            |
| `SKUA_WEATHERKIT_KEY`        | PEM-encoded PKCS8 private key, the .p8 contents   |

All four WeatherKit values must be present to switch the forecast source to
WeatherKit. Missing or invalid credentials fall back to Open-Meteo.

### Pointing the iOS app at the backend

The iOS app has no public backend yet. It reads its base URL from the `skua.api`
default and falls back to a LAN address, so it only reaches weather while on the
same network as a running server. Set `skua.api` in the app to target a hosted
backend once one exists at skuaweather.com.

## Status

The backend serves live data across every source above, with a web app and a
native iOS app on top. The public site collects interest at skuaweather.com. The
domain is registered but the backend is not yet hosted, so clients currently
reach a local server. Interfaces still change freely between releases.

## The name

A skua is a stout seabird that rides storm fronts and makes its living robbing
other birds in mid-air. It reads the weather before anyone else and has no
patience for it. That is the whole idea: honest forecasts with an attitude, from
a bird that has seen every kind of sky. The mark is a cute, chunky skua in profile
with its signature white wing flash, on a near-black storm ground with one
ember-orange accent.

## License

Apache 2.0. See [LICENSE](LICENSE).
