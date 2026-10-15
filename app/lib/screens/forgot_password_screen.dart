import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_error.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../utils/validators.dart';
import '../widgets/club_app_bar.dart';
import '../widgets/error_banner.dart';
import '../widgets/primary_button.dart';

/// Pantalla 4: recuperación de contraseña en dos pasos.
///
/// Paso 1: pedir el correo (`POST /auth/forgot-password`).
/// Paso 2: ingresar el código recibido y la nueva contraseña
/// (`POST /auth/reset-password`).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _emailFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _resetFormKey = GlobalKey<FormState>();

  final TextEditingController _email = TextEditingController();
  final TextEditingController _token = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _passwordRepeat = TextEditingController();

  int _step = 1;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    _passwordRepeat.dispose();
    super.dispose();
  }

  /// Paso 1.
  Future<void> _requestToken() async {
    if (!(_emailFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final String? debugToken =
          await context.read<Session>().auth.requestPasswordReset(_email.text);
      if (!mounted) {
        return;
      }
      setState(() {
        _step = 2;
        _loading = false;
        _info = debugToken == null
            ? 'Si el correo está registrado, te enviamos las instrucciones '
                'para restablecer la contraseña. Revisá tu casilla.'
            : 'Estamos en un entorno de prueba: el código de recuperación '
                'viene en la respuesta de la API y ya lo cargamos acá abajo.';
        if (debugToken != null) {
          _token.text = debugToken;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.userMessage;
        _loading = false;
      });
    }
  }

  /// Paso 2.
  Future<void> _resetPassword() async {
    if (!(_resetFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final String detail = await context.read<Session>().auth.resetPassword(
            token: _token.text,
            newPassword: _password.text,
          );
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail)),
      );
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.userMessage;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: const ClubAppBar(title: 'Recuperar contraseña'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _StepHeader(step: _step),
                const SizedBox(height: 20),
                if (_info != null) ...<Widget>[
                  _InfoBanner(message: _info!),
                  const SizedBox(height: 16),
                ],
                if (_step == 1)
                  Form(
                    key: _emailFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: AppTheme.inputDecoration(
                            'Correo electrónico',
                            hint: 'nombre@dominio.com',
                            prefixIcon: const Icon(Icons.mail_outline),
                          ),
                          validator: Validators.email,
                        ),
                      ],
                    ),
                  )
                else
                  Form(
                    key: _resetFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        TextFormField(
                          controller: _token,
                          autocorrect: false,
                          decoration: AppTheme.inputDecoration(
                            'Código de recuperación',
                            hint: 'Pegá el código que recibiste',
                            prefixIcon: const Icon(Icons.vpn_key_outlined),
                          ),
                          validator: Validators.resetToken,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          obscureText: true,
                          decoration: AppTheme.inputDecoration(
                            'Nueva contraseña',
                            hint: 'Al menos 8 caracteres',
                            prefixIcon: const Icon(Icons.lock_outline),
                          ),
                          validator: Validators.newPassword,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordRepeat,
                          obscureText: true,
                          decoration: AppTheme.inputDecoration(
                            'Repetí la nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_reset),
                          ),
                          validator: (String? value) => Validators.matches(
                            value,
                            _password.text,
                            'las contraseñas',
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 16),
                  ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _step == 1 ? 'Enviar instrucciones' : 'Cambiar contraseña',
                  loading: _loading,
                  onPressed: _step == 1 ? _requestToken : _resetPassword,
                ),
                if (_step == 2)
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _step = 1;
                              _error = null;
                              _info = null;
                            }),
                    child: const Text('Usar otro correo'),
                  ),
                const SizedBox(height: 8),
                Text(
                  _step == 1
                      ? 'Te vamos a enviar un código para restablecer la contraseña.'
                      : 'El código vence a los 30 minutos y se puede usar una sola vez.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        CircleAvatar(
          radius: 14,
          backgroundColor: theme.colorScheme.primary,
          child: Text(
            '$step',
            style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            step == 1
                ? 'Paso 1: ¿cuál es tu correo?'
                : 'Paso 2: ingresá el código y tu nueva contraseña',
            style: theme.textTheme.titleMedium,
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
