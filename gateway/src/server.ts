import { createApp } from './app.js';
import { loadConfig } from './config.js';

try {
  process.loadEnvFile();
} catch {
  // No .env file: rely on variables already in the environment.
}

const config = loadConfig();
if (!config.resrobotApiKey) console.warn('RESROBOT_API_KEY is not set.');
if (!config.geminiApiKey) console.warn('GEMINI_API_KEY is not set.');

createApp({ config }).listen(config.port, () => {
  console.log(`Gateway listening on port ${config.port}`);
});
