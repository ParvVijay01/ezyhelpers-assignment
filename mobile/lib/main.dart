import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mobile/provider/auth_provider.dart';
import 'package:mobile/provider/jobs_provider.dart';
import 'package:mobile/screens/home.dart';
import 'package:mobile/services/api_service.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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