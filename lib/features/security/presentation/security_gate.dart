import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/providers.dart';
import '../../../core/security/external_activity_guard.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/state_views.dart';

class SecurityGate extends ConsumerStatefulWidget {
  const SecurityGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SecurityGate> createState() => _SecurityGateState();
}

class _SecurityGateState extends ConsumerState<SecurityGate>
    with WidgetsBindingObserver {
  static const _deviceLockChannel = MethodChannel('pems.store/device_lock');
  Timer? _externalActivityExitTimer;
  bool _returningFromExternalActivity = false;
  late final ExternalActivityGuard _externalActivityGuard;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _externalActivityGuard = ref.read(externalActivityGuardProvider);
    _externalActivityGuard.onIdle = _onExternalActivityIdle;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _externalActivityExitTimer?.cancel();
    _externalActivityGuard.onIdle = null;
    super.dispose();
  }

  void _onExternalActivityIdle() {
    // Some pickers resolve their Future before Flutter reports `resumed`.
    // Allow that transition, but still lock if the app really stays away.
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      return;
    }
    _externalActivityExitTimer?.cancel();
    _externalActivityExitTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != AppLifecycleState.resumed &&
          !_externalActivityGuard.isActive) {
        _returningFromExternalActivity = false;
        ref.read(authControllerProvider.notifier).lock();
      }
    });
  }

  Future<void> _lockIfDeviceWentToSleep() async {
    try {
      final interactive = await _deviceLockChannel.invokeMethod<bool>(
        'isReadyForBiometrics',
      );
      if (mounted && interactive == false) {
        ref.read(authControllerProvider.notifier).lock();
      }
    } on MissingPluginException {
      // The Android device-state channel does not exist on desktop or in tests.
    } on PlatformException {
      // A failed device-state query must not interrupt the photo flow.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_externalActivityGuard.isActive) {
        _returningFromExternalActivity = true;
        unawaited(_lockIfDeviceWentToSleep());
      } else if (!_returningFromExternalActivity) {
        ref.read(authControllerProvider.notifier).lock();
      } else {
        _onExternalActivityIdle();
      }
    } else if (state == AppLifecycleState.resumed) {
      _externalActivityExitTimer?.cancel();
      _returningFromExternalActivity = false;
      unawaited(ref.read(authControllerProvider.notifier).ensureFreshSession());
    }
  }

  @override
  Widget build(BuildContext context) {
    final authentication = ref.watch(authControllerProvider);
    return authentication.when(
      loading: () => const _AuthSplash(),
      error: (error, _) => _AuthenticationNavigator(
        routeKey: 'authentication-error',
        child: _AuthFailure(
          error: error,
          onRetry: () => ref.invalidate(authControllerProvider),
        ),
      ),
      data: (snapshot) => switch (snapshot.status) {
        AuthStatus.setupRequired => const _AuthenticationNavigator(
          routeKey: 'authentication-setup',
          child: AuthenticationPage(setup: true),
        ),
        AuthStatus.signedOut => _AuthenticationNavigator(
          routeKey: 'authentication-sign-in',
          child: AuthenticationPage(savedIdentifier: snapshot.identifier),
        ),
        AuthStatus.locked => _AuthenticationNavigator(
          routeKey: 'authentication-locked',
          child: AuthenticationPage(
            savedIdentifier: snapshot.identifier,
            autoBiometric: true,
          ),
        ),
        AuthStatus.authenticated => widget.child,
      },
    );
  }
}

/// Authentication is displayed by `MaterialApp.builder`, above the router's
/// Navigator. This private navigator supplies the Overlay required by
/// tooltips, dialogs, autofill and other floating Material widgets.
class _AuthenticationNavigator extends StatelessWidget {
  const _AuthenticationNavigator({required this.routeKey, required this.child});

  final String routeKey;
  final Widget child;

  @override
  Widget build(BuildContext context) => Navigator(
    key: ValueKey(routeKey),
    onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => child),
  );
}

class AuthenticationPage extends ConsumerStatefulWidget {
  const AuthenticationPage({
    super.key,
    this.setup = false,
    this.savedIdentifier,
    this.autoBiometric = false,
  });

  final bool setup;
  final String? savedIdentifier;
  final bool autoBiometric;

  @override
  ConsumerState<AuthenticationPage> createState() => _AuthenticationPageState();
}

class _AuthenticationPageState extends ConsumerState<AuthenticationPage>
    with WidgetsBindingObserver {
  static const _deviceLockChannel = MethodChannel('pems.store/device_lock');
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifier;
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _passwordHidden = true;
  bool _confirmationHidden = true;
  bool _rememberMe = true;
  bool _busy = false;
  bool _autoBiometricTriggered = false;
  Timer? _automaticBiometricTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _identifier = TextEditingController(text: widget.savedIdentifier ?? '');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _automaticBiometricTimer?.cancel();
    _identifier.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleAutomaticBiometric();
    } else {
      _automaticBiometricTimer?.cancel();
      _automaticBiometricTimer = null;
    }
  }

  void _scheduleAutomaticBiometric() {
    if (!mounted ||
        !widget.autoBiometric ||
        _autoBiometricTriggered ||
        _automaticBiometricTimer != null ||
        ref.read(settingsProvider).value?.biometricEnabled != true) {
      return;
    }
    _automaticBiometricTimer = Timer(
      const Duration(milliseconds: 700),
      () async {
        _automaticBiometricTimer = null;
        if (!mounted || _autoBiometricTriggered || _busy) return;
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          return;
        }
        bool ready;
        try {
          ready =
              await _deviceLockChannel.invokeMethod<bool>(
                'isReadyForBiometrics',
              ) ??
              false;
        } on MissingPluginException {
          // Linux et les tests n'ont pas de verrouillage Android à interroger.
          ready = true;
        } on PlatformException {
          return;
        }
        if (!mounted || _autoBiometricTriggered || _busy) return;
        if (!ready) {
          _scheduleAutomaticBiometric();
          return;
        }
        if (WidgetsBinding.instance.lifecycleState !=
            AppLifecycleState.resumed) {
          return;
        }
        _autoBiometricTriggered = true;
        unawaited(_biometric());
      },
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final controller = ref.read(authControllerProvider.notifier);
    final result = widget.setup
        ? await controller.register(
            identifier: _identifier.text,
            password: _password.text,
            rememberMe: _rememberMe,
          )
        : await controller.signIn(
            identifier: _identifier.text,
            password: _password.text,
            rememberMe: _rememberMe,
          );
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => showMessage(context, failure.message, error: true),
      (_) {},
    );
  }

  Future<void> _biometric() async {
    setState(() => _busy = true);
    final result = await ref
        .read(authControllerProvider.notifier)
        .signInWithBiometrics(rememberMe: _rememberMe);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold(
      (failure) => showMessage(context, failure.message, error: true),
      (_) {},
    );
  }

  Future<void> _forgotPassword() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié ?'),
        content: const Text(
          'PeMS Store fonctionne hors connexion et ne transmet jamais votre mot de passe. Il n’existe donc aucune réinitialisation à distance : contactez le propriétaire principal de l’appareil.',
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
    final biometricEnabled =
        ref.watch(settingsProvider).value?.biometricEnabled == true;
    if (widget.autoBiometric && biometricEnabled && !_autoBiometricTriggered) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduleAutomaticBiometric();
      });
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _BrandIntroduction(setup: widget.setup),
                    const SizedBox(height: 22),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('IDENTIFIANT OU E-MAIL'),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _identifier,
                              enabled: !_busy,
                              autofillHints: const [AutofillHints.username],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                prefixIcon: Icon(Icons.account_circle_outlined),
                              ),
                              validator: (value) {
                                final text = value?.trim() ?? '';
                                if (text.length < 3) {
                                  return 'Saisissez au moins 3 caractères.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            _FieldLabel(
                              widget.setup
                                  ? 'CRÉER UN MOT DE PASSE'
                                  : 'MOT DE PASSE',
                            ),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _password,
                              enabled: !_busy,
                              obscureText: _passwordHidden,
                              autofillHints: [
                                widget.setup
                                    ? AutofillHints.newPassword
                                    : AutofillHints.password,
                              ],
                              textInputAction: widget.setup
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              onFieldSubmitted: widget.setup
                                  ? null
                                  : (_) => _submit(),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(
                                          () => _passwordHidden =
                                              !_passwordHidden,
                                        ),
                                  tooltip: _passwordHidden
                                      ? 'Afficher le mot de passe'
                                      : 'Masquer le mot de passe',
                                  icon: Icon(
                                    _passwordHidden
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) => (value ?? '').length < 8
                                  ? 'Saisissez au moins 8 caractères.'
                                  : null,
                            ),
                            if (widget.setup) ...[
                              const SizedBox(height: 15),
                              const _FieldLabel('CONFIRMER LE MOT DE PASSE'),
                              const SizedBox(height: 7),
                              TextFormField(
                                controller: _confirmation,
                                enabled: !_busy,
                                obscureText: _confirmationHidden,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(
                                    Icons.verified_user_outlined,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: _busy
                                        ? null
                                        : () => setState(
                                            () => _confirmationHidden =
                                                !_confirmationHidden,
                                          ),
                                    tooltip: _confirmationHidden
                                        ? 'Afficher la confirmation'
                                        : 'Masquer la confirmation',
                                    icon: Icon(
                                      _confirmationHidden
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                  ),
                                ),
                                validator: (value) => value != _password.text
                                    ? 'Les mots de passe ne correspondent pas.'
                                    : null,
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 32,
                                  child: Checkbox(
                                    value: _rememberMe,
                                    onChanged: _busy
                                        ? null
                                        : (value) => setState(
                                            () => _rememberMe = value ?? true,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Expanded(
                                  child: Text(
                                    'Se souvenir de moi',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                                if (!widget.setup)
                                  TextButton(
                                    onPressed: _busy ? null : _forgotPassword,
                                    child: const Text(
                                      'Mot de passe oublié ?',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _submit,
                                icon: _busy
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.arrow_forward),
                                label: Text(
                                  _busy
                                      ? 'Veuillez patienter…'
                                      : widget.setup
                                      ? 'Créer mon accès'
                                      : 'Se connecter',
                                ),
                              ),
                            ),
                            if (!widget.setup && biometricEnabled) ...[
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _busy ? null : _biometric,
                                  icon: const Icon(Icons.fingerprint),
                                  label: const Text('Utiliser la biométrie'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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

class _BrandIntroduction extends StatelessWidget {
  const _BrandIntroduction({required this.setup});

  final bool setup;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 96,
        height: 96,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.rose.withValues(alpha: .16),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Image.asset('assets/branding/pems_mark_small.png'),
      ),
      const SizedBox(height: 16),
      const _AccessLabel(),
      const SizedBox(height: 10),
      Text(
        setup ? 'Configurez votre accès' : 'Bienvenue sur PeMS Store',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      Text(
        setup
            ? 'Premier lancement : choisissez les identifiants que vous utiliserez lors de vos prochaines connexions.'
            : 'Connectez-vous pour gérer vos stocks et superviser vos activités.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          height: 1.4,
        ),
      ),
    ],
  );
}

class _AccessLabel extends StatelessWidget {
  const _AccessLabel();

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
      letterSpacing: .45,
    ),
  );
}

class _AuthSplash extends StatelessWidget {
  const _AuthSplash();

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 84,
            child: Image.asset('assets/branding/pems_mark_small.png'),
          ),
          const SizedBox(height: 20),
          const CircularProgressIndicator(),
        ],
      ),
    ),
  );
}

class _AuthFailure extends StatelessWidget {
  const _AuthFailure({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  String? get _diagnosticCode {
    final cause = error is AppFailure ? (error as AppFailure).cause : error;
    if (cause == null) return null;
    if (cause is PlatformException) {
      return 'Diagnostic : Android ${cause.code}';
    }
    if (cause is MissingPluginException) {
      return 'Diagnostic : plugin Android indisponible';
    }
    return 'Diagnostic : ${cause.runtimeType}';
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_reset_outlined, size: 52),
            const SizedBox(height: 14),
            const Text(
              'La sécurité locale n’a pas pu démarrer.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_diagnosticCode case final code?) ...[
              const SizedBox(height: 8),
              Text(
                code,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    ),
  );
}
