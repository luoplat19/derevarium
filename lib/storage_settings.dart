import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'backup.dart';
import 'backup_file.dart';
import 'storage_backend.dart';
import 'tree_repository.dart';

class StorageSettingsPage extends StatefulWidget {
  final TreeRepository repository;
  final TreeCollection Function() collection;
  final Future<bool> Function(BackupData) restore;
  const StorageSettingsPage({
    super.key,
    required this.repository,
    required this.collection,
    required this.restore,
  });
  @override
  State<StorageSettingsPage> createState() => _StorageSettingsPageState();
}

class _StorageSettingsPageState extends State<StorageSettingsPage> {
  StorageStatus? status;
  bool busy = false;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    final value = await widget.repository.backend.status();
    if (mounted) setState(() => status = value);
  }

  String size(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КіБ';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МіБ';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} ГіБ';
  }

  void message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> exportBackup() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final collection = widget.collection();
      final now = DateTime.now();
      final backup = BackupData(
        createdAt: now,
        trees: collection.trees,
        unreadable: collection.unreadable,
      );
      final date = now.toIso8601String().replaceAll(':', '-').split('.').first;
      if (await saveBackupFile(backup.encode(), 'derevarium-$date.json')) {
        message(
          'Копію передано на збереження. Вона містить дерева, фото й нотатки.',
        );
      }
    } catch (_) {
      message('Не вдалося зберегти копію у файл. Повтори спробу.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> importBackup() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'Копія Derevarium',
            extensions: ['json'],
            uniformTypeIdentifiers: ['public.json'],
          ),
        ],
      );
      if (file == null) return;
      final backup = BackupData.decode(await file.readAsBytes());
      if (!mounted) return;
      final current = widget.collection();
      final currentIds = current.trees.map((tree) => tree.id).toSet();
      final updated = backup.trees
          .where((tree) => currentIds.contains(tree.id))
          .length;
      final added = backup.trees.length - updated;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Відновити з копії?'),
          content: Text(
            'Додати дерев: $added. Оновити дерев: $updated.\n\nДерева, яких немає у файлі, залишаться в колекції. Фото й нотатки наявних дерев із копії замінять поточні.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Скасувати'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Відновити'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      if (await widget.restore(backup)) {
        message('Колекцію відновлено з копії.');
        await refresh();
      }
    } catch (error) {
      message(
        error is FormatException || error is TypeError
            ? 'Файл копії пошкоджений або має непідтримуваний формат. Колекцію не змінено.'
            : 'Не вдалося прочитати файл копії. Колекцію не змінено.',
      );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> protectStorage() async {
    setState(() => busy = true);
    final granted = await widget.repository.backend.requestPersistence();
    await refresh();
    message(
      granted
          ? 'Браузер надав захист від автоматичного очищення.'
          : 'Браузер не надав захист. Регулярно зберігай копію у файл.',
    );
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final collection = widget.collection();
    return Scaffold(
      appBar: AppBar(title: const Text('Сховище та копії')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.storage_rounded,
                    size: 44,
                    color: AppColors.sage,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Дерев у колекції: ${collection.trees.length}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text('Сховище: ${status?.name ?? 'перевіряємо…'}'),
                  if (status?.usageBytes != null)
                    Text(
                      'Орієнтовно зайнято цим сайтом: ${size(status!.usageBytes!)}',
                    ),
                  if (status?.quotaBytes != null)
                    Text(
                      'Ліміт, наданий браузером: ${size(status!.quotaBytes!)}',
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.shield_outlined, color: AppColors.sage),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  status?.persistent == true
                      ? 'Захист від автоматичного очищення увімкнений.'
                      : 'Регулярно зберігай копію колекції у файл.',
                  style: const TextStyle(color: AppColors.sage),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: busy ? null : exportBackup,
            icon: const Icon(Icons.download),
            label: const Text('Зберегти копію у файл'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : importBackup,
            icon: const Icon(Icons.upload_file),
            label: const Text('Відновити з файлу'),
          ),
          if (status?.name == 'IndexedDB' && status?.persistent != true) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy ? null : protectStorage,
              icon: const Icon(Icons.shield_outlined),
              label: const Text('Захистити сховище'),
            ),
          ],
          if (busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: 20),
          const Text(
            'Дерева зберігаються на цьому пристрої за цією адресою сайту. Копія у файл містить усі фотографії та дозволяє перенести колекцію на інший пристрій.\n\nОчищення даних сайту або видалення браузера може видалити колекцію. Тримай копії файлів поза браузером, наприклад на комп’ютері.',
            style: TextStyle(color: AppColors.sage, height: 1.5),
          ),
        ],
      ),
    );
  }
}
