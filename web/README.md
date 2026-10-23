# skua web

The Skua web client. A SvelteKit app that renders the forecast, the voice, and
the overlays from the Skua backend. It talks only to the backend, never to the
upstream weather sources directly. See the repository root README for the data
sources and the HTTP API.

## Developing

Install dependencies and start the dev server.

```sh
npm install
npm run dev
```

The client reads the backend base URL from `VITE_SKUA_API`, defaulting to
`http://localhost:8080`. Set it to point at a hosted backend once one exists.

## Building

Create and preview a production build.

```sh
npm run build
npm run preview
```
