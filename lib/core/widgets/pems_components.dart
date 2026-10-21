import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/pems_navigation.dart';
import '../theme/app_theme.dart';

class PemsBrandHeader extends StatelessWidget implements PreferredSizeWidget {
  const PemsBrandHeader({
    super.key,
    this.section = 'Accueil',
    this.showBack = false,
    this.showMenu = true,
    this.actions = const [],
  });

  final String section;
  final bool showBack;
  final bool showMenu;
  final List<Widget> actions;

  void _goBack(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
      return;
    }

    // Les écrans ouverts depuis le drawer utilisent `go()`, sans pile de
    // navigation à dépiler. Dans ce cas, la flèche doit tout de même offrir
    // un retour utile vers l'écran principal.
    context.go('/dashboard');
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    leading: showBack
        ? IconButton(
            onPressed: () => _goBack(context),
            tooltip: 'Retour',
            icon: const Icon(Icons.arrow_back),
          )
        : showMenu
        ? IconButton(
            onPressed: () => pemsShellScaffoldKey.currentState?.openDrawer(),
            tooltip: 'Ouvrir le menu',
            icon: const Icon(Icons.menu_rounded),
          )
        : null,
    toolbarHeight: 70,
    titleSpacing: showBack ? 0 : 16,
    title: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Image.asset('assets/branding/pems_mark_small.png'),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PeMS STORE',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                section,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    actions: actions,
  );
}

class PemsSectionTitle extends StatelessWidget {
  const PemsSectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.count,
  });
  final String title;
  final Widget? trailing;
  final int? count;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Row(
          children: [
            Flexible(
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            if (count != null) ...[
              const SizedBox(width: 7),
              PemsPill(label: '$count'),
            ],
          ],
        ),
      ),
      trailing ?? const SizedBox.shrink(),
    ],
  );
}

class PemsPill extends StatelessWidget {
  const PemsPill({
    super.key,
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });
  final String label;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color:
            backgroundColor ?? scheme.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: foregroundColor ?? scheme.onPrimaryContainer,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: foregroundColor ?? scheme.onPrimaryContainer,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class PemsMetricCard extends StatelessWidget {
  const PemsMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.accent,
  });
  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 10,
                      letterSpacing: .5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -.4,
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 3),
              Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PemsActionTile extends StatelessWidget {
  const PemsActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: selected
          ? Theme.of(context).colorScheme.primaryContainer
          : Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            children: [
              Icon(icon, size: 23),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Color stockColor(int stock, int threshold) {
  if (stock == 0) return AppColors.loss;
  if (stock <= threshold) return const Color(0xFFC47A00);
  return AppColors.profit;
}
