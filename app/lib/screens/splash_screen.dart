import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/session.dart';
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
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.sports_tennis, size: 88, color: scheme.onPrimary),
              const SizedBox(height: 20),
              Text(
                'Club Sebastián Martínez Amaray',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reservá tu espacio deportivo',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onPrimary.withAlpha(230)),
              ),
              const SizedBox(height: 32),
              CircularProgressIndicator(color: scheme.onPrimary),
            ],
          ),
        ),
      ),
    );
  }
}
