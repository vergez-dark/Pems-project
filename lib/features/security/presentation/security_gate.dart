import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/state_views.dart';

class SecurityGate extends ConsumerStatefulWidget {
  const SecurityGate({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends ConsumerState<SecurityGate>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  bool _unlocked = false;
  bool _checking = false;
  bool _hidden = true;
  final _identifier = TextEditingController(text: 'Propriétaire principal');
  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _identifier.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) setState(() => _unlocked = false);
  }

  Future<void> _biometric() async {
    setState(() => _checking = true);
    final result = await ref.read(authenticateProvider)();
    if (!mounted) return;
    setState(() => _checking = false);
    result.fold((f) => showMessage(context, f.message, error: true), (ok) {
      if (ok) setState(() => _unlocked = true);
    });
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref.read(verifyPinProvider)(_pin.text);
    if (!mounted) return;
    result.fold((f) => showMessage(context, f.message, error: true), (ok) {
      if (ok) {
        _pin.clear();
        setState(() => _unlocked = true);
      } else {
        showMessage(context, 'Code PIN incorrect.', error: true);
      }
    });
  }

  Future<void> _forgotPin() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Code d’accès oublié ?'),
        content: const Text(
          'PeMS Store fonctionne hors connexion : le code n’est jamais envoyé sur un serveur. Restaurez une sauvegarde connue ou contactez le propriétaire principal pour récupérer l’accès à l’appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final protected =
        settings?.pinEnabled == true || settings?.biometricEnabled == true;
    if (!protected || _unlocked) return widget.child;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Image.asset('assets/branding/pems_mark_small.png'),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: .28),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Gestion Commerciale & Boutiques',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Bienvenue sur PeMS Store',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connectez-vous pour gérer vos stocks et superviser vos activités.',
                      textAlign: TextAlign.center,
                    ),
                    if (settings?.pinEnabled == true) ...[
                      const SizedBox(height: 22),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'IDENTIFIANT OU E-MAIL',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .4,
                                ),
                              ),
                              const SizedBox(height: 7),
                              TextFormField(
                                controller: _identifier,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.account_circle_outlined,
                                  ),
                                  hintText: 'Propriétaire principal',
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Identifiant obligatoire.'
                                    : null,
                              ),
                              const SizedBox(height: 15),
                              const Text(
                                'MOT DE PASSE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: .4,
                                ),
                              ),
                              const SizedBox(height: 7),
                              TextFormField(
                                controller: _pin,
                                autofocus: true,
                                obscureText: _hidden,
                                maxLength: 6,
                                keyboardType: TextInputType.number,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _verify(),
                                decoration: InputDecoration(
                                  labelText: 'Code PIN',
                                  prefixIcon: Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () =>
                                        setState(() => _hidden = !_hidden),
                                    tooltip: _hidden
                                        ? 'Afficher le code'
                                        : 'Masquer le code',
                                    icon: Icon(
                                      _hidden
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    RegExp(r'^\d{4,6}$').hasMatch(value ?? '')
                                    ? null
                                    : 'Saisissez votre code à 4 à 6 chiffres.',
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _forgotPin,
                                  child: const Text('Mot de passe oublié ?'),
                                ),
                              ),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _verify,
                                  icon: const Icon(Icons.arrow_forward),
                                  label: const Text('Se connecter'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (settings?.biometricEnabled == true) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _checking ? null : _biometric,
                          icon: const Icon(Icons.fingerprint),
                          label: Text(
                            _checking
                                ? 'Vérification…'
                                : 'Utiliser la biométrie',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer
                            .withValues(alpha: .18),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.admin_panel_settings_outlined),
                          SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'Accès gestionnaire restreint. Il n’existe aucun écran d’inscription publique.',
                              style: TextStyle(fontSize: 12, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'PeMS Store v1.0 • XAF (FCFA) • Cameroun',
                      style: TextStyle(fontSize: 11),
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
}
