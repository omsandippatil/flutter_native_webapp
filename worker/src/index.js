import { applyCors, handlePreflight } from './middleware/cors.js';
import { checkLimit, rateLimitResponse } from './middleware/rate_limit.js';
import { routeRequest } from './routes/route_table.js';
import { handleTapBuddyChat } from './handlers/tap_buddy_chat.js';
import { handleSubmissionReview } from './handlers/submission_review.js';

export default {
  async fetch(request, env, ctx) {
    if (request.method === 'OPTIONS') {
      return handlePreflight(request, env);
    }

    const limitResult = await checkLimit(request, env);
    if (!limitResult.allowed) {
      return applyCors(rateLimitResponse(limitResult), request, env);
    }

    const url = new URL(request.url);

    try {
      if (request.method === 'POST' && url.pathname === '/tapbuddy/chat') {
        const response = await handleTapBuddyChat(request, env);
        return applyCors(response, request, env);
      }

      if (request.method === 'POST' && url.pathname === '/submission-review/review') {
        const response = await handleSubmissionReview(request, env);
        return applyCors(response, request, env);
      }

      const response = await routeRequest(request, env);
      return applyCors(response, request, env);
    } catch (err) {
      const errorResponse = new Response(
        JSON.stringify({ success: false, error: 'internal_error', detail: err.message }),
        { status: 500, headers: { 'Content-Type': 'application/json' } }
      );
      return applyCors(errorResponse, request, env);
    }
  },
};
