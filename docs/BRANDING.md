# Health Broget identity

The public product name is **Health Broget**. The assistant is **Health Broget Assistant**. Version 1.0.2 applies this identity to Flutter screens, Android labels, the web manifest and metadata, email-facing descriptions in code, and backend assistant responses. Existing Firebase project IDs, public service URLs and Android application ID remain stable so accounts and installed-app updates continue using the same services.

Assets generated with the built-in imagegen tool:

- `assets/branding/health_broget_wordmark_source.png`: original generated transparent horizontal logo.
- `assets/branding/health_broget_wordmark.png`: production 1200×280 transparent wordmark.
- `assets/branding/health_broget_app_logo.png`: original square icon with opaque mint background.
- `assets/branding/health_broget_app_logo_192.png`: compact Flutter icon.

`scripts/generate-icons.mjs` produces the web favicon, standard/maskable PWA icons and native Android launcher/splash artwork. Prior user-supplied originals were retained in ignored `.local/previous-branding` and remain in Git history.

## Wordmark prompt

Use case: logo-brand. Create a finished professional horizontal logo for the nutrition and personal health app named exactly "Health Broget". Transparent background, landscape aspect ratio about 4:1. At left a distinct simple flat geometric symbol: an elegant rounded heart formed by two gently interlocking leaf shapes, subtle negative-space H, conveying nutrition and wellbeing. Symbol must remain recognizable at 24 pixels. At right exact words "Health Broget" on ONE line in beautifully spaced modern rounded sans-serif, semibold, dark forest green #173c31. Symbol forest green #17634b with restrained fresh mint #81b99b accent. Clean solid shapes, flat vector-like edges, no gradients, no shadows, no mockup, no extra text, no tagline, no medical cross, no airplane, no currency/finance icon. Typography perfectly spelled, title case, highly legible. Generous but modest transparent padding; artwork fills most of canvas. This is the actual product logo asset, not a branding presentation.

## App icon prompt

Use case: logo-brand. Create the matching square Android app icon for Health Broget using exactly the heart/leaf H symbol from the reference logo, preserving its distinctive geometry and forest-green/mint palette. Remove all words. Center only the symbol, taking about 65 percent of the square canvas width, with equal safe margins all around. Opaque solid very pale warm mint background #eef5ef extending edge to edge, no rounded-corner framing (Android applies its own mask), no shadow, no texture, no border, no other graphics or text. Crisp polished production app icon, visually consistent with the reference.
