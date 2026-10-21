import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The authentication gate owns first-run account creation. Once it opens the
/// router, this lightweight route forwards to the application dashboard.
class OnboardingGate extends StatelessWidget {
  const OnboardingGate({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/dashboard');
    });
    return const _BrandSplash();
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
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    ),
  );
}
