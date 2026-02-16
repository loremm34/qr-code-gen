import 'package:flutter/material.dart';
import '../../../data/models/deeplink_item.dart';
import 'deeplink_card.dart';

class DeepLinkList extends StatelessWidget {
  final List<DeepLinkItem> items;
  final Future<void> Function(String id, String newLink) onEditLink;
  final Future<void> Function(String id) onDelete;

  const DeepLinkList({
    super.key,
    required this.items,
    required this.onEditLink,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Center(child: Text('Пока пусто. Нажми “Добавить”.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final item = items[i];
        return DeepLinkCard(
          item: item,
          onEditLink: (newLink) => onEditLink(item.id, newLink),
          onDelete: () => onDelete(item.id),
        );
      },
    );
  }
}
