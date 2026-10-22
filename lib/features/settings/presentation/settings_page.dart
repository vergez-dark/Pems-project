import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/pems_components.dart';
import '../domain/app_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _saveSettings(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    String message,
  ) async {
    await ref.read(settingsProvider.notifier).save(settings);
    if (context.mounted) showMessage(context, message);
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final values = await showDialog<({String current, String next})>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (values == null) return;
    final result = await ref
        .read(authControllerProvider.notifier)
        .changePassword(
          currentPassword: values.current,
          newPassword: values.next,
        );
    if (!context.mounted) return;
    result.fold(
      (f) => showMessage(context, f.message, error: true),
      (_) => showMessage(context, 'Mot de passe modifié.'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: const PemsBrandHeader(section: 'Paramètres', showBack: true),
      body: settings.when(
        loading: () => const LoadingCards(),
        error: (error, _) => ErrorState(
          error: error,
          onRetry: () => ref.invalidate(settingsProvider),
        ),
        data: (value) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            _Section(
              title: 'Apparence',
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('Thème'),
                  trailing: SizedBox(
                    width: 138,
                    child: PemsDropdownField<AppThemeMode>(
                      value: value.themeMode,
                      items: const [
                        DropdownMenuItem(
                          value: AppThemeMode.system,
                          child: Text('Système'),
                        ),
                        DropdownMenuItem(
                          value: AppThemeMode.light,
                          child: Text('Clair'),
                        ),
                        DropdownMenuItem(
                          value: AppThemeMode.dark,
                          child: Text('Sombre'),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode == null) return;
                        _saveSettings(
                          context,
                          ref,
                          value.copyWith(themeMode: mode),
                          'Thème mis à jour.',
                        );
                      },
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.payments_outlined),
                  title: const Text('Monnaie'),
                  trailing: Text(
                    value.currency,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Sécurité',
              children: [
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: Text(
                    ref.watch(authControllerProvider).value?.identifier ??
                        'Propriétaire principal',
                  ),
                  subtitle: const Text(
                    'Session de 2 heures, renouvelée automatiquement',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.password_outlined),
                  title: const Text('Modifier le mot de passe'),
                  subtitle: const Text('8 caractères minimum'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _changePassword(context, ref),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Biométrie'),
                  subtitle: const Text(
                    'Empreinte ou verrouillage du téléphone',
                  ),
                  value: value.biometricEnabled,
                  onChanged: (enabled) async {
                    if (enabled) {
                      final result = await ref.read(authenticateProvider)();
                      if (!context.mounted) return;
                      final authenticated = result.fold((f) {
                        showMessage(context, f.message, error: true);
                        return false;
                      }, (ok) => ok);
                      if (!authenticated) return;
                    }
                    await ref
                        .read(settingsProvider.notifier)
                        .save(value.copyWith(biometricEnabled: enabled));
                    if (context.mounted) {
                      showMessage(
                        context,
                        enabled
                            ? 'Biométrie activée.'
                            : 'Biométrie désactivée.',
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.logout,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: Text(
                    'Se déconnecter',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onTap: () async {
                    final result = await ref
                        .read(authControllerProvider.notifier)
                        .signOut();
                    if (!context.mounted) return;
                    result.fold(
                      (failure) =>
                          showMessage(context, failure.message, error: true),
                      (_) => context.go('/'),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Données',
              children: [
                ListTile(
                  leading: const Icon(Icons.cloud_sync_outlined),
                  title: const Text('Sauvegarde et restauration'),
                  subtitle: Text(
                    value.lastBackupAt == null
                        ? 'À configurer'
                        : 'Sauvegarde automatique active',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/backup'),
                ),
                ListTile(
                  leading: const Icon(Icons.warning_amber_outlined),
                  title: const Text('Seuil de stock bas'),
                  trailing: SizedBox(
                    width: 138,
                    child: PemsDropdownField<int>(
                      value: value.lowStockThreshold,
                      items: [1, 2, 3, 5, 10]
                          .map(
                            (amount) => DropdownMenuItem(
                              value: amount,
                              child: Text('$amount paires'),
                            ),
                          )
                          .toList(),
                      onChanged: (amount) {
                        if (amount == null) return;
                        _saveSettings(
                          context,
                          ref,
                          value.copyWith(lowStockThreshold: amount),
                          'Seuil de stock mis à jour.',
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const _Section(
              title: 'À propos',
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('PeMS Store'),
                  subtitle: Text(
                    'Version 1.0.0 • Gestion commerciale & boutiques',
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Confidentialité'),
                  subtitle: Text(
                    'Aucune donnée n’est envoyée hors de votre Google Drive privé.',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Modifier le mot de passe'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              autofocus: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Mot de passe actuel',
              ),
              validator: (value) =>
                  (value ?? '').isEmpty ? 'Champ obligatoire.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
              ),
              validator: (value) =>
                  (value ?? '').length < 8 ? '8 caractères minimum.' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(labelText: 'Confirmation'),
              validator: (value) => value != _next.text
                  ? 'Les mots de passe ne correspondent pas.'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (current: _current.text, next: _next.text));
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      Card(child: Column(children: children)),
    ],
  );
}
