import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/repositories.dart';
import 'routing/app_router.dart';
import 'widgets/common.dart';
import 'services/ai/broget_ai_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();
  try {
    AppConfig.validate();
    await Firebase.initializeApp(options: AppConfig.firebase);
    if (AppConfig.emulators) {
      await FirebaseAuth.instance.useAuthEmulator(AppConfig.emulatorHost, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(
        AppConfig.emulatorHost,
        8080,
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: const AndroidPlayIntegrityProvider(),
        providerWeb: kIsWeb ? ReCaptchaV3Provider(AppConfig.recaptcha) : null,
      );
    }
    if (kIsWeb) await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    // Analytics/Installations and Crashlytics have no local emulators. Do not
    // initialize their SDKs with the deliberately fake demo Firebase key.
    if (!AppConfig.emulators) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
    }
    if (!kIsWeb && !AppConfig.emulators) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      FlutterError.onError = (details) {
        FirebaseCrashlytics.instance.recordError(
          details.exception.runtimeType.toString(),
          details.stack,
          fatal: true,
        );
      };
    }
    runApp(const ProviderScope(child: BrogetApp()));
  } catch (_) {
    runApp(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Panel(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.settings_suggest_outlined, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'BROGET AI could not connect to its services. Please check the application configuration or try again.',
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: main,
                      child: const Text('Retry startup'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BrogetApp extends ConsumerWidget {
  const BrogetApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(sessionProvider, (previous, next) {
      final user = next.value;
      if (user != null && previous?.value?.uid != user.uid) {
        unawaited(
          ref
              .read(userRepositoryProvider)
              .ensureAccount(user)
              .catchError((Object _) {}),
        );
      }
    });
    ref.listen(profileProvider, (previous, next) {
      if (next.value?.health != null && previous?.value?.health == null) {
        // A best-effort in-app check only. FCM background delivery is separate.
        unawaited(
          ref
              .read(apiProvider)
              .prepareHistory()
              .then((_) async {
                await ref
                    .read(apiProvider)
                    .request('POST', '/notifications/check', {});
              })
              .catchError((Object _) {}),
        );
      }
    });
    return MaterialApp.router(
      title: 'BROGET AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) =>
          SessionGate(child: child ?? const SizedBox.shrink()),
    );
  }
}
