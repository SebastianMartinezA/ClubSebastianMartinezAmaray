import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';
import 'login_screen.dart';

/// Pantalla de arranque: decide si hay una sesión guardada y a dónde ir.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _decideRoute();
    });
  }

  Future<void> _decideRoute() async {
    final Session session = context.read<Session>();
    final bool restored = await session.restore();
    if (!mounted) {
      return;
    }
    final Widget destination =
        restored ? const HomeScreen() : const LoginScreen();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (BuildContext _) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Background of the app (#050508), logo and name in white, and the lime
    // reserved for the loading indicator: one accent per screen, like the rest
    // of the design system.
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.sports_tennis,
                size: 88,
                color: AppColors.textPrimary,
              ),
              const SizedBox(height: 20),
              Text(
                'Club Sebastián Martínez Amaray',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Reservá tu espacio deportivo',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: AppColors.lime),
            ],
          ),
        ),
      ),
    );
  }
}
