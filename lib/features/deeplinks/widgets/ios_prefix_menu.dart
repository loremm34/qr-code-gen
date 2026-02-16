import 'package:flutter/material.dart';
import '../controller/deeplink_controller.dart';

class IosPrefixMenu extends StatelessWidget {
  final DeepLinkController controller;

  const IosPrefixMenu({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.isLoading) return const SizedBox.shrink();

    return PopupMenuButton<_PrefixAction>(
      tooltip: 'iOS prefix',
      itemBuilder: (context) {
        final items = <PopupMenuEntry<_PrefixAction>>[];

        items.add(
          PopupMenuItem<_PrefixAction>(
            enabled: false,
            child: Text(
              'iOS prefix: ${controller.selectedIosPrefix}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        );

        items.add(const PopupMenuDivider());

        for (final p in controller.iosPrefixes) {
          items.add(
            PopupMenuItem<_PrefixAction>(
              value: _PrefixAction.select(p),
              child: Row(
                children: [
                  Expanded(child: Text(p)),
                  if (p == controller.selectedIosPrefix)
                    const Icon(Icons.check, size: 18),
                ],
              ),
            ),
          );
        }

        items.add(const PopupMenuDivider());

        items.add(
          const PopupMenuItem<_PrefixAction>(
            value: _PrefixAction.add(),
            child: Row(
              children: [
                Icon(Icons.add, size: 18),
                SizedBox(width: 8),
                Text('Добавить prefix…'),
              ],
            ),
          ),
        );

        return items;
      },
      onSelected: (action) async {
        if (action.type == _PrefixActionType.select) {
          await controller.selectIosPrefix(action.payload!);
          return;
        }

        if (action.type == _PrefixActionType.add) {
          final value = await _showAddDialog(context);
          if (value != null) await controller.addIosPrefix(value);
          return;
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.link),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                controller.selectedIosPrefix,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<String?> _showAddDialog(BuildContext context) async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Добавить iOS prefix'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Prefix',
              hintText: 'example://',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(context, v);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }
}

enum _PrefixActionType { select, add }

class _PrefixAction {
  final _PrefixActionType type;
  final String? payload;

  const _PrefixAction._(this.type, this.payload);

  const _PrefixAction.add() : this._(_PrefixActionType.add, null);
  const _PrefixAction.select(String prefix)
    : this._(_PrefixActionType.select, prefix);
}
