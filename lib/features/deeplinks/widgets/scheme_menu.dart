import 'package:flutter/material.dart';

import '../controller/deeplink_controller.dart';
import 'node_dialogs.dart';

/// Переключатель схемы (всё, что до `://`).
/// Активная схема подставляется во все диплинки сразу.
class SchemeMenu extends StatelessWidget {
  final DeepLinkController controller;

  const SchemeMenu({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopupMenuButton<_SchemeAction>(
      tooltip: 'Схема диплинков',
      itemBuilder: (context) => [
        const PopupMenuItem(
          enabled: false,
          child: Text('Активная схема'),
        ),
        for (final scheme in controller.schemes)
          PopupMenuItem(
            value: _SchemeAction.select(scheme),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: scheme == controller.selectedScheme
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
                Expanded(child: Text(scheme)),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: _SchemeAction.add(),
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.add),
            title: Text('Добавить схему…'),
          ),
        ),
        const PopupMenuItem(
          value: _SchemeAction.rename(),
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Переименовать активную'),
          ),
        ),
        PopupMenuItem(
          value: const _SchemeAction.delete(),
          enabled: controller.schemes.length > 1,
          child: const ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline),
            title: Text('Удалить активную'),
          ),
        ),
      ],
      onSelected: (action) => _handle(context, action),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alternate_email, size: 18),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                controller.selectedScheme,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Future<void> _handle(BuildContext context, _SchemeAction action) async {
    switch (action.type) {
      case _SchemeActionType.select:
        await controller.selectScheme(action.payload!);

      case _SchemeActionType.add:
        final value = await showSchemeDialog(context);
        if (value != null) await controller.addScheme(value);

      case _SchemeActionType.rename:
        final value = await showSchemeDialog(
          context,
          initial: controller.selectedScheme,
        );
        if (value != null) {
          await controller.renameScheme(controller.selectedScheme, value);
        }

      case _SchemeActionType.delete:
        if (controller.schemes.length <= 1) return;
        final ok = await confirmDelete(
          context,
          title: 'Удалить схему?',
          message:
              '«${controller.selectedScheme}» исчезнет из списка. '
              'Диплинки останутся, но будут строиться по другой схеме.',
        );
        if (ok) await controller.deleteScheme(controller.selectedScheme);
    }
  }
}

enum _SchemeActionType { select, add, rename, delete }

class _SchemeAction {
  final _SchemeActionType type;
  final String? payload;

  const _SchemeAction._(this.type, this.payload);

  const _SchemeAction.select(String scheme)
    : this._(_SchemeActionType.select, scheme);
  const _SchemeAction.add() : this._(_SchemeActionType.add, null);
  const _SchemeAction.rename() : this._(_SchemeActionType.rename, null);
  const _SchemeAction.delete() : this._(_SchemeActionType.delete, null);
}
