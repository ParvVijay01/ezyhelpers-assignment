import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logging/logging.dart';
import 'package:mobile/core/app_logger.dart';
import 'package:mobile/provider/auth_provider.dart';
import 'package:mobile/provider/jobs_provider.dart';
import 'package:mobile/screens/home.dart';
import 'package:mobile/services/api_service.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogging();

  final log = Logger('main');

  FlutterError.onError = (details) {
    log.severe('Flutter framework error', details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    log.severe('Uncaught platform error', error, stack);
    return true;
  };

  await dotenv.load(fileName: '.env');

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
    log.fine('Firebase default app already initialized');
  }

  log.info('Starting app (api: ${dotenv.env['BASE_URL']}, debug: $kDebugMode)');

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(
          create: (_) => ApiService(),
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (context) =>
              AuthProvider(apiService: context.read<ApiService>()),
        ),
        ChangeNotifierProxyProvider<AuthProvider, JobsProvider>(
          create: (context) =>
              JobsProvider(apiService: context.read<ApiService>()),
          update: (_, auth, jobs) => jobs!..setToken(auth.token),
        ),
      ],
      child: const EzyHelpersApp(),
    ),
  );
}
