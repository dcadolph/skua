// API_BASE is the base URL of the Skua backend. Override at build time with the
// VITE_SKUA_API environment variable.
export const API_BASE: string = import.meta.env.VITE_SKUA_API ?? 'http://localhost:8080';
