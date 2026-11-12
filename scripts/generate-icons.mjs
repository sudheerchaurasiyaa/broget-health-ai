import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';
import { mkdir, copyFile, writeFile } from 'node:fs/promises';

const require = createRequire(new URL('../backend/package.json', import.meta.url));
const sharp = require('sharp');
const root = new URL('../', import.meta.url);
const path = relative => fileURLToPath(new URL(relative, root));
const appLogo = path('assets/branding/health_broget_app_logo.png');
const fullLogo = path('assets/branding/health_broget_wordmark.png');
await sharp(path('assets/branding/health_broget_wordmark_source.png')).trim()
  .resize(1168, 248, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
  .extend({ top: 16, bottom: 16, left: 16, right: 16, background: { r: 0, g: 0, b: 0, alpha: 0 } })
  .png().toFile(fullLogo);

// Keep both source PNGs byte-for-byte intact. All resizing writes derivatives.
await sharp(appLogo).resize(192, 192).png().toFile(path('assets/branding/health_broget_app_logo_192.png'));
await mkdir(path('web/branding'), { recursive: true });
await copyFile(fullLogo, path('web/branding/health_broget_wordmark.png'));
for (const size of [192, 512]) {
  await sharp(appLogo).resize(size, size).png().toFile(path(`web/icons/Icon-${size}.png`));
  const inset = Math.round(size * .14), innerSize = size - inset * 2;
  const inner = await sharp(appLogo).resize(innerSize, innerSize).png().toBuffer();
  await sharp({ create: { width: size, height: size, channels: 4, background: '#eef5ef' } })
    .composite([{ input: inner, left: inset, top: inset }]).png().toFile(path(`web/icons/Icon-maskable-${size}.png`));
}
await sharp(appLogo).resize(48, 48).png().toFile(path('web/favicon.png'));

for (const [density, size] of [['mdpi', 48], ['hdpi', 72], ['xhdpi', 96], ['xxhdpi', 144], ['xxxhdpi', 192]]) {
  const directory = `android/app/src/main/res/mipmap-${density}`;
  await mkdir(path(directory), { recursive: true });
  await sharp(appLogo).resize(size, size).png().toFile(path(`${directory}/ic_launcher.png`));
}
await mkdir(path('android/app/src/main/res/drawable-nodpi'), { recursive: true });
await sharp(appLogo).resize(512, 512).png().toFile(path('android/app/src/main/res/drawable-nodpi/broget_app_logo.png'));
const adaptiveInner = await sharp(appLogo).resize(288, 288).png().toBuffer();
await sharp({ create: { width: 432, height: 432, channels: 4, background: '#eef5ef' } })
  .composite([{ input: adaptiveInner, left: 72, top: 72 }]).png().toFile(path('android/app/src/main/res/drawable-nodpi/broget_adaptive_foreground.png'));
await mkdir(path('android/app/src/main/res/mipmap-anydpi-v26'), { recursive: true });
await writeFile(path('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml'), '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n  <background android:drawable="@color/broget_icon_background"/>\n  <foreground android:drawable="@drawable/broget_adaptive_foreground"/>\n</adaptive-icon>\n');
console.log('Generated launcher, splash, web and Flutter compact icons from the supplied app artwork; full-logo transparency preserved.');
