import { validateAccessToken, unauthorizedResponse } from './auth.js';
import { callGroq, callGroqVision, callGroqAudioTranscription } from './groq.js';

const SYSTEM_PROMPT = `You are an assessment assistant for a school learning app reviewing a student's submitted answer.
Evaluate the submission against the given question and expected answer criteria.
Respond ONLY with a JSON object with this exact shape and no extra text:
{"score": number between 0 and 100, "verdict": "pass" or "review" or "fail", "feedback": short encouraging feedback string, "sms_text": very short friendly message under 200 characters either appreciating the student or gently pointing to one improvement, "strengths": array of short strings, "improvements": array of short strings}`;

const MAX_TEXT_CHARS = 4000;
const VISION_MODEL = 'llama-4-scout-17b-16e-instruct';

function buildUserLines(question, expectedAnswer, rubric) {
  const lines = [];
  if (question) lines.push(`Question: ${String(question).slice(0, MAX_TEXT_CHARS)}`);
  if (expectedAnswer)
    lines.push(`Expected answer criteria: ${String(expectedAnswer).slice(0, MAX_TEXT_CHARS)}`);
  if (rubric) lines.push(`Rubric: ${String(rubric).slice(0, MAX_TEXT_CHARS)}`);
  return lines;
}

function parseReview(rawContent) {
  return JSON.parse(rawContent);
}

function formatReviewResponse(learnerId, review) {
  return {
    success: true,
    learner_id: learnerId || null,
    review: {
      score: review.score ?? null,
      verdict: review.verdict ?? null,
      feedback: review.feedback ?? '',
      sms_text: review.sms_text ?? '',
      strengths: Array.isArray(review.strengths) ? review.strengths : [],
      improvements: Array.isArray(review.improvements) ? review.improvements : [],
    },
  };
}

async function reviewTextSubmission(env, question, expectedAnswer, rubric, submissionText) {
  const lines = buildUserLines(question, expectedAnswer, rubric);
  lines.push(`Student submission: ${submissionText.slice(0, MAX_TEXT_CHARS)}`);

  const messages = [
    { role: 'system', content: SYSTEM_PROMPT },
    { role: 'user', content: lines.join('\n') },
  ];

  return callGroq(env, {
    model: env.GROQ_MODEL,
    messages,
    temperature: 0.2,
    maxTokens: 600,
    responseFormat: { type: 'json_object' },
  });
}

async function reviewImageSubmission(
  env,
  question,
  expectedAnswer,
  rubric,
  imageUrl,
  submissionText
) {
  const lines = buildUserLines(question, expectedAnswer, rubric);
  lines.push('The student submitted the attached image as their answer.');
  if (submissionText)
    lines.push(`Additional student notes: ${submissionText.slice(0, MAX_TEXT_CHARS)}`);

  const messages = [
    { role: 'system', content: SYSTEM_PROMPT },
    {
      role: 'user',
      content: [
        { type: 'text', text: lines.join('\n') },
        { type: 'image_url', image_url: { url: imageUrl } },
      ],
    },
  ];

  return callGroqVision(env, {
    model: VISION_MODEL,
    messages,
    temperature: 0.2,
    maxTokens: 600,
    responseFormat: { type: 'json_object' },
  });
}

async function reviewAudioSubmission(env, question, expectedAnswer, rubric, audioUrl) {
  const transcript = await callGroqAudioTranscription(env, { audioUrl });
  const lines = buildUserLines(question, expectedAnswer, rubric);
  lines.push(
    `Student submission (transcribed from audio): ${transcript.text.slice(0, MAX_TEXT_CHARS)}`
  );

  const messages = [
    { role: 'system', content: SYSTEM_PROMPT },
    { role: 'user', content: lines.join('\n') },
  ];

  const result = await callGroq(env, {
    model: env.GROQ_MODEL,
    messages,
    temperature: 0.2,
    maxTokens: 600,
    responseFormat: { type: 'json_object' },
  });

  return { ...result, transcript: transcript.text };
}

export async function handleSubmissionReview(request, env) {
  let body;
  try {
    body = await request.json();
  } catch {
    body = {};
  }

  const phone = body.phone;
  const learnerId = body.learner_id;
  const question = body.question;
  const expectedAnswer = body.expected_answer;
  const rubric = body.rubric;
  const submissionType = body.submission_type || 'text';
  const submissionText = body.submission_text;
  const imageUrl = body.image_url;
  const audioUrl = body.audio_url;

  const authResult = await validateAccessToken(request, env, phone);
  if (!authResult.valid) {
    return unauthorizedResponse(authResult.error);
  }

  if (submissionType === 'text' && (!submissionText || typeof submissionText !== 'string')) {
    return new Response(JSON.stringify({ success: false, error: 'submission_text_is_required' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  if (submissionType === 'image' && (!imageUrl || typeof imageUrl !== 'string')) {
    return new Response(JSON.stringify({ success: false, error: 'image_url_is_required' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  if (submissionType === 'audio' && (!audioUrl || typeof audioUrl !== 'string')) {
    return new Response(JSON.stringify({ success: false, error: 'audio_url_is_required' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  if (!['text', 'image', 'audio'].includes(submissionType)) {
    return new Response(JSON.stringify({ success: false, error: 'invalid_submission_type' }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    });
  }

  try {
    let result;
    if (submissionType === 'text') {
      result = await reviewTextSubmission(env, question, expectedAnswer, rubric, submissionText);
    } else if (submissionType === 'image') {
      result = await reviewImageSubmission(
        env,
        question,
        expectedAnswer,
        rubric,
        imageUrl,
        submissionText
      );
    } else {
      result = await reviewAudioSubmission(env, question, expectedAnswer, rubric, audioUrl);
    }

    let review;
    try {
      review = parseReview(result.content);
    } catch {
      return new Response(
        JSON.stringify({ success: false, error: 'invalid_model_response', raw: result.content }),
        { status: 502, headers: { 'Content-Type': 'application/json' } }
      );
    }

    const responseBody = formatReviewResponse(learnerId, review);
    if (result.transcript) responseBody.transcript = result.transcript;

    return new Response(JSON.stringify(responseBody), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (err) {
    const status = err.status && err.status >= 400 && err.status < 600 ? err.status : 502;
    return new Response(
      JSON.stringify({
        success: false,
        error: 'submission_review_failed',
        detail: err.message,
        groq_error: err.groqError || null,
      }),
      { status, headers: { 'Content-Type': 'application/json' } }
    );
  }
}
