if (process.env.APP_ENV !== 'development') throw new Error('Local server requires APP_ENV=development');
if (!process.env.FIRESTORE_EMULATOR_HOST || !process.env.FIREBASE_AUTH_EMULATOR_HOST) throw new Error('Local development requires Auth and Firestore emulators');
const { app } = await import('./app.js');
app.listen(Number(process.env.PORT ?? 8787), '0.0.0.0', () => console.log('BROGET local API ready'));
