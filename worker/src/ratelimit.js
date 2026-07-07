const OTP_ROUTE_PREFIXES = ["/tapapp/api/auth/send_otp", "/tapapp/api/auth/forgot_password_send_otp"];

const OTP_LIMIT = 5;
const OTP_WINDOW_SECONDS = 3600;

const DEFAULT_LIMIT = 60;
const DEFAULT_WINDOW_SECONDS = 60;

function isOtpRoute(pathname) {
  return OTP_ROUTE_PREFIXES.some((prefix) => pathname.startsWith(prefix));
}

function clientIp(request) {
  return request.headers.get("CF-Connecting-IP") || "unknown";
}

export async function checkLimit(request, env) {
  const url = new URL(request.url);
  const ip = clientIp(request);
  const otp = isOtpRoute(url.pathname);
  const limit = otp ? OTP_LIMIT : DEFAULT_LIMIT;
  const windowSeconds = otp ? OTP_WINDOW_SECONDS : DEFAULT_WINDOW_SECONDS;
  const key = `rl:${otp ? "otp" : "default"}:${ip}`;

  const current = await env.KV.get(key);
  const count = current ? parseInt(current, 10) : 0;

  if (count >= limit) {
    return { allowed: false, remaining: 0, limit };
  }

  if (count === 0) {
    await env.KV.put(key, "1", { expirationTtl: windowSeconds });
  } else {
    await env.KV.put(key, String(count + 1), { expirationTtl: windowSeconds });
  }

  return { allowed: true, remaining: limit - (count + 1), limit };
}

export function rateLimitResponse(result) {
  return new Response(
    JSON.stringify({ success: false, error: "rate_limited" }),
    {
      status: 429,
      headers: {
        "Content-Type": "application/json",
        "Retry-After": "60",
      },
    }
  );
}