import { readFile, writeFile } from 'node:fs/promises';
const root = new URL('../build/web/', import.meta.url);
const pubspec = await readFile(new URL('../pubspec.yaml', import.meta.url), 'utf8');
const version = encodeURIComponent(pubspec.match(/^version:\s*(\S+)/m)[1]);
let html = await readFile(new URL('index.html', root), 'utf8');
html = html.replace(/src="flutter_bootstrap\.js(?:\?[^"]*)?"/, `src="flutter_bootstrap.js?v=${version}"`)
  .replace('href="favicon.png"', `href="favicon.png?v=${version}"`)
  .replace('href="manifest.json"', `href="manifest.json?v=${version}"`);
await writeFile(new URL('index.html', root), html);
const bootstrapPath = new URL('flutter_bootstrap.js', root);
const bootstrap = await readFile(bootstrapPath, 'utf8');
await writeFile(bootstrapPath, bootstrap.replace(/"mainJsPath":"main\.dart\.js(?:\?[^"]*)?"/g, `"mainJsPath":"main.dart.js?v=${version}"`));
for (const [path, title, description] of [
  ['about', 'About Health Broget', 'Understand food-photo estimates, nutrition tracking and the Health Broget Assistant.'],
  ['features', 'Nutrition features | Health Broget', 'Track meals, review food scans, explore nutrition reports and ask your assistant.'],
  ['how-it-works', 'How it works | Health Broget', 'Take a photo, review food and portion estimates, confirm your meal and understand your patterns.'],
  ['download', 'Health Broget for Android', 'Use Health Broget on Android or in your browser. Check official APK availability.'],
  ['privacy', 'Privacy policy | Health Broget', 'How your account, nutrition records, photos and assistant conversations are processed.'],
  ['terms', 'Terms of service | Health Broget', 'Nutrition estimates, service limitations and responsible use of Health Broget.'],
]) {
  const page = html.replace('<title>Health Broget · Everyday nutrition, understood.</title>', `<title>${title}</title>`).replace('content="Photo-assisted food logging, private nutrition tracking and insights for your everyday routine."', `content="${description}"`).replace('<h1>Everyday nutrition, understood.</h1>', `<h1>${title}</h1>`);
  await writeFile(new URL(`${path}.html`, root), page);
}
