import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/api_error.dart';
import '../models/user.dart';
import '../state/session.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/validators.dart';
import '../widgets/club_app_bar.dart';
import '../widgets/error_banner.dart';
import '../widgets/info_row.dart';
import '../widgets/primary_button.dart';
import 'login_screen.dart';

/// Pantalla 11: perfil.
///
/// Se pueden editar nombre, apellido y fecha de nacimiento (`PATCH /users/me`).
/// El correo se muestra deshabilitado porque la API no lo permite cambiar
/// (`400 email_not_editable`).
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _email;

  DateTime? _birthDate;
  bool _loading = false;
  bool _signingOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final User? user = context.read<Session>().user;
    _firstName = TextEditingController(text: user?.firstName ?? '');
    _lastName = TextEditingController(text: user?.lastName ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _birthDate = user?.birthDate;
    _refresh();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    super.dispose();
  }

  /// Brings the profile from `GET /users/me` when the screen opens.
  Future<void> _refresh() async {
    final Session session = context.read<Session>();
    await session.refreshUser();
    if (!mounted) {
      return;
    }
    final User? user = session.user;
    if (user != null) {
      setState(() {
        _firstName.text = user.firstName;
        _lastName.text = user.lastName;
        _email.text = user.email;
        _birthDate = user.birthDate;
      });
    }
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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Session session = context.read<Session>();
      final User updated = await session.auth.updateProfile(
        firstName: _firstName.text,
        lastName: _lastName.text,
        birthDate: _birthDate,
      );
      session.setUser(updated);
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado.')),
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

  Future<void> _signOut() async {
    final Session session = context.read<Session>();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Vas a tener que ingresar de nuevo para reservar.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _signingOut = true);
    await session.signOut();
    if (!mounted) {
      return;
    }
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (BuildContext _) => const LoginScreen()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final User? user = context.watch<Session>().user;

    return Scaffold(
      appBar: const ClubAppBar(title: 'Mi perfil'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            shape: RoundedRectangleBorder(borderRadius: AppTheme.borderRadius),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  InfoRow(
                    label: 'Usuario',
                    value: user == null ? '—' : '#${user.id}',
                    icon: Icons.badge_outlined,
                  ),
                  InfoRow(
                    label: 'Correo',
                    value: user?.email ?? '—',
                    icon: Icons.mail_outline,
                  ),
                  InfoRow(
                    label: 'Miembro desde',
                    value: user?.createdAt == null
                        ? '—'
                        : Formatters.date(user!.createdAt!.toLocal()),
                    icon: Icons.event_outlined,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Mis datos', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: <Widget>[
                TextFormField(
                  controller: _firstName,
                  textCapitalization: TextCapitalization.words,
                  decoration: AppTheme.inputDecoration('Nombre'),
                  validator: (String? value) =>
                      Validators.required(value, 'tu nombre'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lastName,
                  textCapitalization: TextCapitalization.words,
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _email,
                  enabled: false,
                  decoration: AppTheme.inputDecoration(
                    'Correo electrónico',
                    prefixIcon: const Icon(Icons.mail_outline),
                    enabled: false,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'El correo no se puede modificar.',
                  style: theme.textTheme.bodySmall,
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
            label: 'Guardar cambios',
            loading: _loading,
            onPressed: _save,
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar sesión'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
