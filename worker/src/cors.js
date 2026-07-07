const ALLOWED_ORIGINS = new Set([
  "https://yourapp.example.com",
  "http://localhost:3000",
  "http://localhost:8080",
]);

function resolveOrigin(request) {
  const origin = request.headers.get("Origin");
  if (!origin) return "*";
  return ALLOWED_ORIGINS.has(origin) ? origin : null;
}

export function corsHeaders(request) {
  const origin = resolveOrigin(request);
  const headers = {
    "Access-Control-Allow-Methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Flutter-Authorization",
    "Access-Control-Max-Age": "86400",
    "Vary": "Origin",
  };
  if (origin) {
    headers["Access-Control-Allow-Origin"] = origin;
  }
  return headers;
}

export function applyCors(response, request) {
  const headers = new Headers(response.headers);
  const cors = corsHeaders(request);
  for (const key in cors) {
    headers.set(key, cors[key]);
  }
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

export function handlePreflight(request) {
  return new Response(null, {
    status: 204,
    headers: corsHeaders(request),
  });
}