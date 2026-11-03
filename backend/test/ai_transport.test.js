import test from 'node:test';
import assert from 'node:assert/strict';
import { generateStructured, AiTransportError } from '../src/ai_transport.js';
import { assistantOutput } from '../src/contracts.js';

const payload = { contents: [{ role: 'user', parts: [{ text: 'Synthetic test request' }] }] };
const valid = { text: 'Hello from your nutrition assistant.', tool: null };
const success = () => new Response(JSON.stringify({ candidates: [{ finishReason: 'STOP', content: { parts: [{ text: JSON.stringify(valid) }] } }] }), { status: 200 });
const config = { key: 'test-key-never-log', model: 'test-model', sleep: async () => {} };

test('temporary overload retries the identical structured request and recovers', async () => {
  const requests = [];
  const result = await generateStructured(payload, assistantOutput, { ...config, fetchImpl: async (url, options) => {
    requests.push({ url, ...options });
    return requests.length === 1 ? new Response('unavailable', { status: 503 }) : success();
  } });
  assert.deepEqual(result, valid);
  assert.equal(requests.length, 2);
  assert.equal(requests[0].body, requests[1].body);
  assert.equal(JSON.parse(requests[0].body).generationConfig.responseMimeType, 'application/json');
});
test('retired model errors are explicit and never retried or leaked', async () => {
  let calls = 0;
  await assert.rejects(generateStructured(payload, assistantOutput, { ...config, fetchImpl: async () => {
    calls++; return new Response('sensitive upstream test-key-never-log', { status: 404 });
  } }), error => error instanceof AiTransportError && error.code === 'assistant-model-unavailable' && error.upstreamStatus === 404 && !error.message.includes(config.key));
  assert.equal(calls, 1);
});
test('persistent overload and network failures stop after three attempts', async () => {
  for (const mode of ['overload', 'network']) {
    let calls = 0;
    await assert.rejects(generateStructured(payload, assistantOutput, { ...config, fetchImpl: async () => {
      calls++;
      if (mode === 'network') throw new Error('network detail with private data');
      return new Response('', { status: 503 });
    } }), error => error.code === (mode === 'network' ? 'assistant-timeout' : 'assistant-busy'));
    assert.equal(calls, 3);
  }
});
test('invalid generated JSON is not accepted and can recover on retry', async () => {
  let calls = 0;
  const result = await generateStructured(payload, assistantOutput, { ...config, fetchImpl: async () => {
    calls++;
    return calls === 1 ? new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: 'not json' }] } }] }), { status: 200 }) : success();
  } });
  assert.equal(calls, 2); assert.deepEqual(result, valid);
});
test('rate limiting, configuration failures and safety blocks are not retried', async () => {
  for (const [status, code] of [[429, 'rate-limited'], [403, 'assistant-configuration-error'], [400, 'assistant-request-rejected']]) {
    let calls = 0;
    await assert.rejects(generateStructured(payload, assistantOutput, { ...config, fetchImpl: async () => { calls++; return new Response('', { status }); } }), error => error.code === code);
    assert.equal(calls, 1);
  }
  await assert.rejects(generateStructured(payload, assistantOutput, { ...config, fetchImpl: async () => new Response(JSON.stringify({ promptFeedback: { blockReason: 'SAFETY' } }), { status: 200 }) }), error => error.code === 'assistant-content-blocked');
});
test('internal thought parts are excluded from the validated response', async () => {
  const result = await generateStructured(payload, assistantOutput, { ...config, fetchImpl: async () => new Response(JSON.stringify({ candidates: [{ content: { parts: [{ thought: true, text: 'private reasoning' }, { text: JSON.stringify(valid) }] } }] }), { status: 200 }) });
  assert.deepEqual(result, valid);
});
