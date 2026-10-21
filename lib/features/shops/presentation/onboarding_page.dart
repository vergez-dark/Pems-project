import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
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
          Image.asset('assets/branding/icon.png', width: 112, height: 112),
          const SizedBox(height: 18),
          Text(
            'Pasora',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    ),
  );
}

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});
  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _controller = PageController();
  int _index = 0;

  static const slides = [
    (
      Icons.inventory_2_rounded,
      'Votre stock, enfin clair',
      'Suivez chaque paire, pointure et couleur, même sans connexion.',
    ),
    (
      Icons.trending_up_rounded,
      'Chaque franc compte',
      'Pasora calcule coûts, bénéfices et parts vendeuses sans approximation.',
    ),
    (
      Icons.backup_rounded,
      'Vos données vous suivent',
      'Sauvegardez sur votre espace privé Google Drive et restaurez sur un nouveau téléphone.',
    ),
  ];

  Future<void> _finish() async {
    final current = ref.read(settingsProvider).value ?? const AppSettings();
    await ref
        .read(settingsProvider.notifier)
        .save(current.copyWith(onboardingDone: true));
    if (mounted) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Column(
          children: [
            Row(
              children: [
                Image.asset('assets/branding/icon.png', width: 44, height: 44),
                const SizedBox(width: 10),
                Text(
                  'Pasora',
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                TextButton(onPressed: _finish, child: const Text('Passer')),
              ],
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (value) => setState(() => _index = value),
                itemCount: slides.length,
                itemBuilder: (_, index) {
                  final slide = slides[index];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 184,
                        height: 184,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(52),
                        ),
                        child: Icon(
                          slide.$1,
                          size: 84,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 42),
                      Text(
                        slide.$2,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        slide.$3,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                slides.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 8,
                  width: index == _index ? 28 : 8,
                  decoration: BoxDecoration(
                    color: index == _index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _index == slides.length - 1
                    ? _finish
                    : () => _controller.nextPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                      ),
                child: Text(
                  _index == slides.length - 1
                      ? 'Nouvelle installation'
                      : 'Continuer',
                ),
              ),
            ),
            if (_index == slides.length - 1)
              TextButton.icon(
                onPressed: () => context.push('/backup'),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('Restaurer mes données'),
              ),
          ],
        ),
      ),
    ),
  );
}
