import 'package:flutter/material.dart';
import 'package:mobile/provider/auth_provider.dart';
import 'package:mobile/screens/job_screen.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/theme/theme.dart';
import 'package:provider/provider.dart';

class EzyHelpersApp extends StatelessWidget {
  const EzyHelpersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EzyHelpers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  late final Future<bool> _autoLoginFuture;

  @override
  void initState() {
    super.initState();
    _autoLoginFuture = context.read<AuthProvider>().tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _autoLoginFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        return Consumer<AuthProvider>(
          builder: (context, auth, _) =>
              auth.isAuthenticated ? const JobsScreen() : const LoginScreen(),
        );
      },
    );
  }
}