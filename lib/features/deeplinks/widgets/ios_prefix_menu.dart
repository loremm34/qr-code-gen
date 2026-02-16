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

        // existing prefixes
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

        items.add(
          PopupMenuItem<_PrefixAction>(
            value: const _PrefixAction.delete(),
            enabled: controller.iosPrefixes.length > 1,
            child: const Row(
              children: [
                Icon(Icons.delete_outline, size: 18),
                SizedBox(width: 8),
                Text('Удалить prefix…'),
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

        if (action.type == _PrefixActionType.delete) {
          final value = await _showDeleteDialog(
            context,
            controller.iosPrefixes,
          );
          if (value != null) await controller.deleteIosPrefix(value);
          return;
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(Icons.link),
            const SizedBox(width: 8),
            Text(controller.selectedIosPrefix, overflow: TextOverflow.ellipsis),
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

  Future<String?> _showDeleteDialog(
    BuildContext context,
    List<String> prefixes,
  ) async {
    String? selected = prefixes.first;
    return showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Удалить iOS prefix'),
          content: SizedBox(
            width: 520,
            child: DropdownButtonFormField<String>(
              value: selected,
              items: prefixes
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => selected = v),
              decoration: const InputDecoration(
                labelText: 'Выбери prefix для удаления',
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
                if (prefixes.length <= 1) return;
                Navigator.pop(context, selected);
              },
              child: const Text('Удалить'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PrefixActionType { select, add, delete }

class _PrefixAction {
  final _PrefixActionType type;
  final String? payload;

  const _PrefixAction._(this.type, this.payload);

  const _PrefixAction.add() : this._(_PrefixActionType.add, null);
  const _PrefixAction.delete() : this._(_PrefixActionType.delete, null);
  const _PrefixAction.select(String prefix)
    : this._(_PrefixActionType.select, prefix);
}
