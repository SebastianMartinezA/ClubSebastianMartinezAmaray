import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_error.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/club_app_bar.dart';
import '../widgets/error_banner.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';

/// Pantalla 3: registro de usuario.
///
/// El correo ya registrado se informa con "Ya existe una cuenta con ese
/// correo." (código `email_already_registered`).
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _firstName = TextEditingController();
  final TextEditingController _lastName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  DateTime? _birthDate;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial =
        _birthDate ?? DateTime(now.year - 25, now.month, now.day);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Elegí tu fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null && mounted) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_birthDate == null) {
      setState(() => _error = 'Elegí tu fecha de nacimiento.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await context.read<Session>().signUp(
            email: _email.text,
            password: _password.text,
            firstName: _firstName.text,
            lastName: _lastName.text,
            birthDate: _birthDate,
          );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (BuildContext _) => const HomeScreen()),
      );
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
      appBar: const ClubAppBar(title: 'Crear cuenta'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text('Tus datos', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _firstName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: AppTheme.inputDecoration('Nombre'),
                    validator: (String? value) =>
                        Validators.required(value, 'tu nombre'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _lastName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: AppTheme.inputDecoration('Apellido'),
                    validator: (String? value) =>
                        Validators.required(value, 'tu apellido'),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: _pickBirthDate,
                    borderRadius: AppTheme.borderRadius,
                    child: InputDecorator(
                      decoration: AppTheme.inputDecoration(
                        'Fecha de nacimiento',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        suffixIcon: const Icon(Icons.calendar_today, size: 18),
                      ),
                      child: Text(
                        _birthDate == null
                            ? 'Elegí una fecha'
                            : Formatters.date(_birthDate!),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text('Datos de acceso', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: AppTheme.inputDecoration(
                      'Correo electrónico',
                      hint: 'nombre@dominio.com',
                      prefixIcon: const Icon(Icons.mail_outline),
                    ),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: AppTheme.inputDecoration(
                      'Contraseña',
                      hint: 'Al menos 8 caracteres',
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: Validators.newPassword,
                    onFieldSubmitted: (String _) => _submit(),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 16),
                    ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Crear mi cuenta',
                    loading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed:
                        _loading ? null : () => Navigator.of(context).maybePop(),
                    child: const Text('Ya tengo cuenta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
