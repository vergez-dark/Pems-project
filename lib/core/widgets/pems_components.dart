import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../navigation/pems_navigation.dart';
import '../theme/app_theme.dart';

class PemsDropdownField<T> extends StatelessWidget {
  const PemsDropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.label,
    this.hint,
    this.leadingIcon,
    this.enabled = true,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;
  final IconData? leadingIcon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final selected = items.where((item) => item.value == value).firstOrNull;
    final active = enabled && onChanged != null && items.isNotEmpty;
    return Material(
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: active ? () => _showChoices(context) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                Icon(leadingIcon, size: 21, color: scheme.primary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label != null) ...[
                      Text(
                        label!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 3),
                    ],
                    DefaultTextStyle.merge(
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: active
                            ? scheme.onSurface
                            : scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      child: selected?.child ?? Text(hint ?? 'Sélectionner'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChoices(BuildContext context) async {
    final chosen = await showModalBottomSheet<_PemsDropdownChoice<T>>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _PemsDropdownSheet<T>(
        title: label ?? hint ?? 'Sélectionner',
        value: value,
        items: items,
      ),
    );
    if (context.mounted && chosen != null) onChanged?.call(chosen.value);
  }
}

class _PemsDropdownChoice<T> {
  const _PemsDropdownChoice(this.value);
  final T? value;
}

class _PemsDropdownSheet<T> extends StatefulWidget {
  const _PemsDropdownSheet({
    required this.title,
    required this.value,
    required this.items,
  });

  final String title;
  final T? value;
  final List<DropdownMenuItem<T>> items;

  @override
  State<_PemsDropdownSheet<T>> createState() => _PemsDropdownSheetState<T>();
}

class _PemsDropdownSheetState<T> extends State<_PemsDropdownSheet<T>> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visible = widget.items.where((item) {
      if (_query.isEmpty) return true;
      final text = item.child is Text
          ? ((item.child as Text).data ?? '')
          : item.value?.toString() ?? '';
      return text.toLowerCase().contains(_query.toLowerCase());
    }).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .75,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              if (widget.items.length > 7)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                  child: TextField(
                    autofocus: true,
                    onChanged: (query) => setState(() => _query = query),
                    decoration: const InputDecoration(
                      hintText: 'Rechercher…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final item = visible[index];
                    final selected = item.value == widget.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: selected
                            ? scheme.primaryContainer.withValues(alpha: .4)
                            : scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: item.enabled
                              ? () => Navigator.pop(
                                  context,
                                  _PemsDropdownChoice<T>(item.value),
                                )
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Expanded(child: item.child),
                                if (selected) ...[
                                  const SizedBox(width: 10),
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: scheme.primary,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PemsPhoto extends StatelessWidget {
  const PemsPhoto({
    super.key,
    required this.photoPath,
    this.width = 56,
    this.height = 56,
    this.borderRadius = 16,
    this.placeholderIcon = Icons.storefront_rounded,
  });

  final String? photoPath;
  final double width;
  final double height;
  final double borderRadius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    final hasPhoto = path != null && path.isNotEmpty && File(path).existsSync();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: hasPhoto
          ? Image.file(
              File(path),
              width: width,
              height: height,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _placeholder(context),
            )
          : _placeholder(context),
    );
  }

  Widget _placeholder(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Theme.of(context).colorScheme.primaryContainer,
          Theme.of(context).colorScheme.secondaryContainer,
        ],
      ),
    ),
    child: Icon(
      placeholderIcon,
      size: width * .42,
      color: Theme.of(context).colorScheme.onPrimaryContainer,
    ),
  );
}

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
