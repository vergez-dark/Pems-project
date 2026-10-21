import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/app_settings.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _setPin(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
    bool enabled,
  ) async {
    if (!enabled) {
      await ref
          .read(settingsProvider.notifier)
          .save(settings.copyWith(pinEnabled: false));
      return;
    }
    final controller = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Créer un code PIN'),
        content: TextField(
          controller: controller,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: '4 à 6 chiffres'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Activer'),
          ),
        ],
      ),
    );
    if (pin == null) return;
    final result = await ref.read(setPinProvider)(pin);
    if (!context.mounted) return;
    result.fold(
      (f) => showMessage(context, f.message, error: true),
      (_) => ref
          .read(settingsProvider.notifier)
          .save(settings.copyWith(pinEnabled: true)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Réglages')),
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
                  trailing: DropdownButton<AppThemeMode>(
                    value: value.themeMode,
                    underline: const SizedBox.shrink(),
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
                    onChanged: (mode) => ref
                        .read(settingsProvider.notifier)
                        .save(value.copyWith(themeMode: mode)),
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
                SwitchListTile(
                  secondary: const Icon(Icons.pin_outlined),
                  title: const Text('Code PIN'),
                  subtitle: const Text('Protection locale au lancement'),
                  value: value.pinEnabled,
                  onChanged: (enabled) => _setPin(context, ref, value, enabled),
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
                  trailing: DropdownButton<int>(
                    value: value.lowStockThreshold,
                    underline: const SizedBox.shrink(),
                    items: [1, 2, 3, 5, 10]
                        .map(
                          (amount) => DropdownMenuItem(
                            value: amount,
                            child: Text('$amount paires'),
                          ),
                        )
                        .toList(),
                    onChanged: (amount) => ref
                        .read(settingsProvider.notifier)
                        .save(value.copyWith(lowStockThreshold: amount)),
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
                  title: Text('Pasora'),
                  subtitle: Text('Version 1.0.0 • Vos pas, vos profits'),
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
