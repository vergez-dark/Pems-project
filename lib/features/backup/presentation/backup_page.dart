import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/pems_components.dart';
import '../../settings/domain/app_settings.dart';
import '../domain/backup_record.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});
  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage> {
  bool _busy = false;

  Future<void> _backup(bool drive) async {
    setState(() => _busy = true);
    final result = await ref.read(createBackupProvider)(uploadToDrive: drive);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold((f) => showMessage(context, f.message, error: true), (
      record,
    ) async {
      ref.invalidate(backupsProvider);
      final settings = ref.read(settingsProvider).value ?? const AppSettings();
      await ref
          .read(settingsProvider.notifier)
          .save(settings.copyWith(lastBackupAt: record.date));
      if (mounted) {
        showMessage(
          context,
          record.status == BackupStatus.uploaded
              ? 'Sauvegarde envoyée sur Google Drive.'
              : drive
              ? 'Sauvegarde locale créée. Envoi Drive indisponible.'
              : 'Sauvegarde locale créée.',
        );
      }
    });
  }

  Future<void> _restore(BackupRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Restaurer cette sauvegarde ?'),
        content: const Text(
          'Une copie locale de sécurité sera créée, puis les données actuelles seront remplacées.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    final result = await ref.read(restoreBackupProvider)(record);
    if (!mounted) return;
    setState(() => _busy = false);
    result.fold((f) => showMessage(context, f.message, error: true), (_) {
      ref.invalidate(shopsProvider);
      ref.invalidate(dashboardProvider);
      showMessage(context, 'Données restaurées avec succès.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final backups = ref.watch(backupsProvider);
    final last = ref.watch(settingsProvider).value?.lastBackupAt;
    final isLinux = defaultTargetPlatform == TargetPlatform.linux;
    return Scaffold(
      appBar: const PemsBrandHeader(section: 'Sauvegarde', showBack: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.cloud_done_rounded,
                    size: 38,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    last == null
                        ? 'Aucune sauvegarde récente'
                        : 'Dernière sauvegarde\n${DateFormat('d MMM yyyy à HH:mm', 'fr_FR').format(last)}',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLinux
                        ? 'Sur Linux, les sauvegardes sont conservées localement.'
                        : 'Base de données, réglages et photos dans l’espace privé de votre compte Google.',
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (!isLinux)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _busy ? null : () => _backup(true),
                            icon: const Icon(Icons.cloud_upload_outlined),
                            label: const Text('Drive'),
                          ),
                        ),
                      if (!isLinux) const SizedBox(width: 10),
                      IconButton.filledTonal(
                        onPressed: _busy ? null : () => _backup(false),
                        icon: Icon(
                          isLinux ? Icons.save_alt : Icons.phone_android,
                        ),
                        tooltip: 'Copie locale',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Historique',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          Expanded(
            child: backups.when(
              loading: () => const LoadingCards(),
              error: (error, _) => ErrorState(
                error: error,
                onRetry: () => ref.invalidate(backupsProvider),
              ),
              data: (items) => items.isEmpty
                  ? const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'Historique vide',
                      message: 'Votre première sauvegarde apparaîtra ici.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(backupsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final item = items[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: Icon(
                                item.status == BackupStatus.uploaded
                                    ? Icons.cloud_done_outlined
                                    : Icons.phone_android_outlined,
                              ),
                              title: Text(
                                DateFormat(
                                  'EEEE d MMM yyyy',
                                  'fr_FR',
                                ).format(item.date),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                '${DateFormat('HH:mm').format(item.date)} • ${(item.size / 1024).ceil()} Ko • ${item.status == BackupStatus.uploaded ? 'Drive' : 'Locale'}',
                              ),
                              trailing: IconButton(
                                onPressed: _busy ? null : () => _restore(item),
                                icon: const Icon(Icons.restore_rounded),
                                tooltip: 'Restaurer',
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
