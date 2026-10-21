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
  bool _unlocked = false;
  bool _checking = false;
  final _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/branding/icon.png',
                    width: 92,
                    height: 92,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Pasora est verrouillé',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Authentifiez-vous pour accéder à vos données.',
                    textAlign: TextAlign.center,
                  ),
                  if (settings?.pinEnabled == true) ...[
                    const SizedBox(height: 22),
                    TextField(
                      controller: _pin,
                      autofocus: true,
                      obscureText: true,
                      maxLength: 6,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _verify(),
                      decoration: const InputDecoration(
                        labelText: 'Code PIN',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _verify,
                        child: const Text('Déverrouiller'),
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
                          _checking ? 'Vérification…' : 'Utiliser la biométrie',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
