// cors.js
// Applies CORS headers to every outgoing response.
// Allowed origins: your Flutter web app domain + localhost for dev.
// Also allows null origin for Flutter native apps (which send no origin header).
//
// applyCors(response, request): adds Access-Control headers to a Response.
// handlePreflight(request): returns a 204 response for OPTIONS preflight.
//
// Call handlePreflight first in worker.js before routing.
// Wrap every handler response with applyCors before returning.
