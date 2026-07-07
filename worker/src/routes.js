import { validateAccessToken, tokenNeedsRefresh, issueAccessToken, unauthorizedResponse } from "./auth.js";

export const ROUTES = [
  { method: "POST", path: "/auth/check-phone", target: "tap_lms.tapapp.api.auth.tapapp_auth.check_phone", auth: false },
  { method: "POST", path: "/auth/send-otp", target: "tap_lms.tapapp.api.auth.tapapp_auth.send_otp", auth: false },
  { method: "POST", path: "/auth/verify-otp", target: "tap_lms.tapapp.api.auth.tapapp_auth.verify_otp", auth: false },
  { method: "POST", path: "/auth/login", target: "tap_lms.tapapp.api.auth.tapapp_auth.login_with_password", auth: false },
  { method: "POST", path: "/auth/forgot-password/send-otp", target: "tap_lms.tapapp.api.auth.tapapp_auth.forgot_password_send_otp", auth: false },
  { method: "POST", path: "/auth/forgot-password/verify-otp", target: "tap_lms.tapapp.api.auth.tapapp_auth.forgot_password_verify_otp", auth: false },
  { method: "POST", path: "/auth/reset-password", target: "tap_lms.tapapp.api.auth.tapapp_auth.reset_password", auth: false },

  { method: "GET", path: "/profiles", target: "tap_lms.tapapp.api.auth.tapapp_auth.get_profiles", auth: true },
  { method: "GET", path: "/profiles/search", target: "tap_lms.tapapp.api.auth.tapapp_auth.search_profiles", auth: true },
  { method: "POST", path: "/profiles/select", target: "tap_lms.tapapp.api.profile.profile.select_profile", auth: true },
  { method: "POST", path: "/profiles/avatar", target: "tap_lms.tapapp.api.profile.profile.update_avatar", auth: true },
  { method: "POST", path: "/profiles/update", target: "tap_lms.tapapp.api.profile.profile.update_profile", auth: true },

  { method: "GET", path: "/learner/state", target: "tap_lms.tapapp.api.progress.learner.get_learner_state", auth: true },
  { method: "POST", path: "/learner/enroll", target: "tap_lms.tapapp.api.progress.learner.enroll_course", auth: true },
  { method: "POST", path: "/learner/activity", target: "tap_lms.tapapp.api.progress.learner.record_activity", auth: true },
  { method: "POST", path: "/learner/content-progress", target: "tap_lms.tapapp.api.progress.learner.update_content_progress", auth: true },

  { method: "GET", path: "/achievements", target: "tap_lms.tapapp.api.progress.achievements.get_learner_achievements", auth: false },
];

function matchRoute(method, pathname) {
  return ROUTES.find((r) => r.method === method && r.path === pathname) || null;
}

async function readBody(request) {
  const method = request.method;
  if (method === "GET" || method === "HEAD") return {};
  const contentType = request.headers.get("Content-Type") || "";
  if (contentType.includes("application/json")) {
    try {
      return await request.json();
    } catch {
      return {};
    }
  }
  return {};
}

function queryParams(url) {
  const params = {};
  for (const [key, value] of url.searchParams.entries()) {
    params[key] = value;
  }
  return params;
}

export async function routeRequest(request, env) {
  const url = new URL(request.url);
  const route = matchRoute(request.method, url.pathname);

  if (!route) {
    return new Response(JSON.stringify({ success: false, error: "not_found" }), {
      status: 404,
      headers: { "Content-Type": "application/json" },
    });
  }

  const body = await readBody(request);
  const params = { ...queryParams(url), ...body };

  let refreshedToken = null;
  if (route.auth) {
    const result = await validateAccessToken(request, env, params.phone);
    if (!result.valid) {
      return unauthorizedResponse(result.error);
    }
    if (tokenNeedsRefresh(result.payload)) {
      refreshedToken = await issueAccessToken(result.payload.phone, env);
    }
  }

  const backendUrl = `${env.FRAPPE_BASE_URL}/api/method/${route.target}`;

  const forwardHeaders = { "Content-Type": "application/json" };
  const authHeader = request.headers.get("Authorization");
  const flutterAuthHeader = request.headers.get("X-Flutter-Authorization");
  if (authHeader) forwardHeaders["Authorization"] = authHeader;
  if (flutterAuthHeader) forwardHeaders["X-Flutter-Authorization"] = flutterAuthHeader;

  const backendResponse = await fetch(backendUrl, {
    method: request.method === "GET" ? "GET" : "POST",
    headers: forwardHeaders,
    body: request.method === "GET" ? undefined : JSON.stringify(params),
  });

  const responseBody = await backendResponse.text();

  if (refreshedToken) {
    try {
      const parsed = JSON.parse(responseBody);
      parsed.token = refreshedToken;
      return new Response(JSON.stringify(parsed), {
        status: backendResponse.status,
        headers: { "Content-Type": "application/json" },
      });
    } catch {
      return new Response(responseBody, {
        status: backendResponse.status,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  return new Response(responseBody, {
    status: backendResponse.status,
    headers: { "Content-Type": "application/json" },
  });
}