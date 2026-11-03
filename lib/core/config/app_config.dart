import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class AppConfig {
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
  static const emulators = bool.fromEnvironment(
    'USE_EMULATORS',
    defaultValue: true,
  );
  static const emulatorHost = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: 'localhost',
  );
  static const apiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8787',
  );
  static const downloadUrl = String.fromEnvironment('APP_DOWNLOAD_URL');
  static const recaptcha = String.fromEnvironment('RECAPTCHA_SITE_KEY');
  static bool get production => environment != 'development';
  static const firebase = FirebaseOptions(
    apiKey: kIsWeb
        ? String.fromEnvironment(
            'FIREBASE_API_KEY',
            defaultValue: 'demo-public-key',
          )
        : String.fromEnvironment(
            'FIREBASE_ANDROID_API_KEY',
            defaultValue: String.fromEnvironment(
              'FIREBASE_API_KEY',
              defaultValue: 'demo-public-key',
            ),
          ),
    appId: kIsWeb
        ? String.fromEnvironment(
            'FIREBASE_APP_ID',
            defaultValue: '1:123456789:web:broget',
          )
        : String.fromEnvironment(
            'FIREBASE_ANDROID_APP_ID',
            defaultValue: '1:123456789:android:broget',
          ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
      defaultValue: '123456789',
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'demo-broget',
    ),
    authDomain: String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: 'demo-broget.firebaseapp.com',
    ),
  );
  static void validate() {
    if (!['development', 'staging', 'production'].contains(environment)) {
      throw StateError('Invalid environment');
    }
    if (!emulators &&
        (firebase.apiKey.isEmpty ||
            firebase.apiKey == 'demo-public-key' ||
            firebase.appId.isEmpty ||
            firebase.projectId.isEmpty ||
            firebase.projectId.startsWith('demo-'))) {
      throw StateError('Live Firebase identifiers are missing');
    }
    if (production &&
        (emulators ||
            !apiUrl.startsWith('https://') ||
            firebase.projectId.startsWith('demo-') ||
            (kIsWeb && recaptcha.isEmpty))) {
      throw StateError('Production service configuration is incomplete');
    }
    if (const String.fromEnvironment('AI_API_KEY') != '' ||
        const String.fromEnvironment('DEV_AI_API_KEY') != '') {
      throw StateError(
        'Server credentials cannot be supplied to the application',
      );
    }
  }
}
