import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/models/deeplink_item.dart';
import 'edit_deeplink_dialog.dart';

class DeepLinkCard extends StatelessWidget {
  final DeepLinkItem item;
  final Future<void> Function(String newLink) onEditLink;
  final Future<void> Function() onDelete;

  const DeepLinkCard({
    super.key,
    required this.item,
    required this.onEditLink,
    required this.onDelete,
  });

  Future<void> _edit(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => EditDeepLinkDialog(initialLink: item.deepLink),
    );
    if (result == null) return;
    await onEditLink(result);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: Text(
          '“${item.title}” будет удалено без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok == true) await onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Редактировать диплинк',
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit),
                ),
                IconButton(
                  tooltip: 'Удалить',
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            if (item.description.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(item.description),
            ],
            const SizedBox(height: 12),
            SelectableText(
              item.deepLink,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: QrImageView(
                data: item
                    .deepLink, // QR автоматически меняется, когда меняется deepLink
                size: 160,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
