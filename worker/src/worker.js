// worker.js
// Cloudflare Worker entry point.
// Handles all incoming fetch events.
// Pipeline for every request:
//   1. cors.js — apply CORS headers; handle preflight OPTIONS.
//   2. ratelimit.js — check request rate per IP; return 429 if exceeded.
//   3. routes.js — match method + path to the correct handler.
// All route handlers live in routes.js.
// DB and KV bindings are passed from env into handlers via routes.js.
