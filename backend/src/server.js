import { validateHostedEnvironment } from './runtime_config.js';

const { port } = validateHostedEnvironment(process.env);
const { app } = await import('./app.js');
const server = app.listen(port, '0.0.0.0', () => console.log('BROGET hosted API ready'));
process.once('SIGTERM', () => {
  server.close(() => process.exit(0));
  setTimeout(() => process.exit(1), 10000).unref();
});
