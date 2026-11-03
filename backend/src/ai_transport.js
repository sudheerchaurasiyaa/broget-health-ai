import { z } from 'zod';

export class AiTransportError extends Error {
  constructor(status, code, upstreamStatus = null) {
    super(code);
    this.status = status;
    this.code = code;
    this.upstreamStatus = upstreamStatus;
  }
}

// Injected transport/sleep keep retries and error mapping independently testable.
export async function generateStructured(parts, schema, {
  key = process.env.AI_API_KEY,
  model = process.env.AI_MODEL,
  fetchImpl = fetch,
  sleep = ms => new Promise(resolve => setTimeout(resolve, ms)),
} = {}) {
  if (!key || !model) throw new AiTransportError(503, 'assistant-not-configured');
  const body = JSON.stringify({
    ...parts,
    generationConfig: {
      temperature: 0.2, maxOutputTokens: 4096,
      responseMimeType: 'application/json', responseJsonSchema: z.toJSONSchema(schema),
    },
  });
  for (let attempt = 0; attempt < 3; attempt++) {
    let response;
    try {
      response = await fetchImpl(`https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`, {
        method: 'POST', headers: { 'content-type': 'application/json', 'x-goog-api-key': key },
        signal: AbortSignal.timeout(20000), body,
      });
    } catch {
      if (attempt < 2) { await sleep(500 * 2 ** attempt); continue; }
      throw new AiTransportError(504, 'assistant-timeout');
    }
    if (!response.ok) {
      // Never forward raw error bodies: they may contain implementation details.
      if ([500, 502, 503, 504].includes(response.status) && attempt < 2) {
        await response.body?.cancel();
        await sleep(750 * 2 ** attempt);
        continue;
      }
      const code = response.status === 429 ? 'rate-limited'
        : response.status === 404 ? 'assistant-model-unavailable'
        : [401, 403].includes(response.status) ? 'assistant-configuration-error'
        : response.status === 400 ? 'assistant-request-rejected'
        : 'assistant-busy';
      await response.body?.cancel();
      throw new AiTransportError(response.status === 429 ? 429 : 503, code, response.status);
    }
    try {
      const result = await response.json();
      if (result.promptFeedback?.blockReason || ['SAFETY', 'BLOCKLIST', 'PROHIBITED_CONTENT'].includes(result.candidates?.[0]?.finishReason)) {
        throw new AiTransportError(422, 'assistant-content-blocked');
      }
      const raw = result.candidates?.[0]?.content?.parts
        ?.filter(p => typeof p.text === 'string' && !p.thought).map(p => p.text).join('');
      return schema.parse(JSON.parse(raw));
    } catch (error) {
      if (error instanceof AiTransportError) throw error;
      if (attempt === 2) throw new AiTransportError(502, 'invalid-analysis');
    }
  }
}
