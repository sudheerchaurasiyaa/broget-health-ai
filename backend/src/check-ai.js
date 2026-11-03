// Checks real generation, not just model listings (which can include retired IDs).
// Uses only synthetic diagnostic prompts, never account data, images or secrets.
import { generateStructured, AiTransportError } from './ai_transport.js';
import { assistantOutput, recognitionSchema } from './contracts.js';

const checks = [
  ['chat', assistantOutput, 'This is a service health check. Return a brief nutrition greeting and tool=null.'],
  ['food response schema', recognitionSchema, 'This is a synthetic schema compatibility test, not a real meal. Return a hypothetical 100 g rice estimate with approximate per100g nutrition (calories, protein, carbs, fat, fiber), confidence 0.5, unit g, alternatives=[], needsUserConfirmation=true and notes explaining that this is only a diagnostic.'],
];
for (const [name, schema, text] of checks) {
  try {
    await generateStructured({ contents: [{ role: 'user', parts: [{ text }] }] }, schema);
    console.log(`AI ${name} generation passed with a validated structured response.`);
  } catch (error) {
    const code = error instanceof AiTransportError ? error.code : 'service-unavailable';
    console.error(`AI ${name} generation failed: ${code}. No credentials or request content were logged.`);
    process.exitCode = 1;
    break;
  }
}
