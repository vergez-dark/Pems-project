import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';
import '../../settings/domain/app_settings.dart';

class OnboardingGate extends ConsumerWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return settings.when(
      loading: () => const _BrandSplash(),
      error: (_, _) => const OnboardingPage(),
      data: (value) {
        if (value.onboardingDone) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/dashboard');
          });
          return const _BrandSplash();
        }
        return const OnboardingPage();
      },
    );
  }
}

class _BrandSplash extends StatelessWidget {
  const _BrandSplash();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 116,
            height: 116,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer
                  .withValues(alpha: .45),
              borderRadius: BorderRadius.circular(32),
            ),
            child: Image.asset('assets/branding/pems_mark_small.png'),
          ),
          const SizedBox(height: 18),
          Text('PeMS Store', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Gestion commerciale & boutiques',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    ),
  );
}

/// Première connexion du propriétaire principal déjà provisionné localement.
/// Aucun compte public n'est créé ici : seul le secret local est initialisé.
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  bool _hidden = true;
  bool _remember = true;
  bool _busy = false;

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final result = await ref.read(setPinProvider)(_pin.text);
    if (!mounted) return;
    final failure = result.fold((value) => value, (_) => null);
    if (failure != null) {
      setState(() => _busy = false);
      showMessage(context, failure.message, error: true);
      return;
    }
    final current = ref.read(settingsProvider).value ?? const AppSettings();
    await ref
        .read(settingsProvider.notifier)
        .save(current.copyWith(onboardingDone: true, pinEnabled: _remember));
    if (!mounted) return;
    setState(() => _busy = false);
    context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.rose.withValues(alpha: .18),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Image.asset('assets/branding/pems_mark_small.png'),
                  ),
                  const SizedBox(height: 14),
                  const PemsAccessLabel(),
                  const SizedBox(height: 10),
                  Text(
                    'Bienvenue sur PeMS Store',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Première connexion : sécurisez l’accès du propriétaire principal avant de gérer vos boutiques.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('IDENTIFIANT'),
                          const SizedBox(height: 7),
                          const TextField(
                            enabled: false,
                            decoration: InputDecoration(
                              prefixIcon: Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                              hintText: 'Propriétaire principal',
                            ),
                          ),
                          const SizedBox(height: 15),
                          const _FieldLabel('NOUVEAU CODE D’ACCÈS'),
                          const SizedBox(height: 7),
                          TextFormField(
                            controller: _pin,
                            obscureText: _hidden,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.lock_outline),
                              hintText: '4 à 6 chiffres',
                              counterText: '',
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _hidden = !_hidden),
                                icon: Icon(
                                  _hidden
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                                tooltip: _hidden ? 'Afficher' : 'Masquer',
                              ),
                            ),
                            validator: (value) {
                              if (!RegExp(r'^\d{4,6}$').hasMatch(value ?? '')) {
                                return 'Saisissez 4 à 6 chiffres.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _confirmation,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.verified_user_outlined),
                              labelText: 'Confirmer le code',
                              counterText: '',
                            ),
                            validator: (value) => value != _pin.text
                                ? 'Les codes ne correspondent pas.'
                                : null,
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _remember,
                            title: const Text(
                              'Protéger PeMS Store au lancement',
                              style: TextStyle(fontSize: 13),
                            ),
                            onChanged: (value) =>
                                setState(() => _remember = value ?? true),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _activate,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward),
                              label: Text(
                                _busy ? 'Activation…' : 'Activer mon accès',
                              ),
                            ),
                          ),
                          Center(
                            child: TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => context.push('/backup'),
                              icon: const Icon(Icons.cloud_download_outlined),
                              label: const Text('Restaurer une sauvegarde'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer
                          .withValues(alpha: .2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.admin_panel_settings_outlined),
                        SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Accès gestionnaire restreint',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Aucune inscription publique. Les accès supplémentaires sont administrés par le propriétaire principal.',
                                style: TextStyle(fontSize: 12, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'PeMS Store v1.0 • XAF (FCFA) • Cameroun',
                    style: TextStyle(color: AppColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class PemsAccessLabel extends StatelessWidget {
  const PemsAccessLabel({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer
          .withValues(alpha: .25),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'Gestion Commerciale & Boutiques',
      style: TextStyle(fontSize: 11, color: AppColors.roseDark),
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: .5,
    ),
  );
}
