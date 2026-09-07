import 'package:flutter/material.dart';

import '../../../data/models/tree_node.dart';
import '../controller/deeplink_controller.dart';
import 'node_dialogs.dart';

/// Левая панель — «файловая система» с папками и диплинками.
class TreePanel extends StatelessWidget {
  final DeepLinkController controller;

  const TreePanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <_Row>[];
    _collect(null, 0, rows);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(controller: controller),
        const Divider(height: 1),
        Expanded(
          child: DragTarget<String>(
            onWillAcceptWithDetails: (details) =>
                controller.nodeById(details.data)?.parentId != null,
            onAcceptWithDetails: (details) => controller.move(details.data, null),
            builder: (context, candidate, _) => Container(
              color: candidate.isEmpty
                  ? null
                  : theme.colorScheme.primary.withValues(alpha: 0.06),
              child: rows.isEmpty
                  ? _EmptyTree(controller: controller)
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: rows.length,
                      itemBuilder: (context, i) => _NodeRow(
                        controller: controller,
                        node: rows[i].node,
                        depth: rows[i].depth,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  void _collect(String? parentId, int depth, List<_Row> out) {
    for (final node in controller.childrenOf(parentId)) {
      out.add(_Row(node, depth));
      if (node.isFolder && node.expanded) {
        _collect(node.id, depth + 1, out);
      }
    }
  }
}

class _Row {
  final TreeNode node;
  final int depth;

  _Row(this.node, this.depth);
}

class _Header extends StatelessWidget {
  final DeepLinkController controller;

  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    final target = controller.selectedNode;
    final targetName = target == null
        ? 'в корне'
        : 'в «${target.isFolder ? target.title : (controller.nodeById(target.parentId)?.title ?? 'корне')}»';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Диплинки',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          IconButton(
            tooltip: 'Создать папку $targetName',
            icon: const Icon(Icons.create_new_folder_outlined),
            onPressed: () => createFolderIn(context, controller, target?.id),
          ),
          IconButton(
            tooltip: 'Создать диплинк $targetName',
            icon: const Icon(Icons.add_link),
            onPressed: () => createLinkIn(context, controller, target?.id),
          ),
        ],
      ),
    );
  }
}

class _EmptyTree extends StatelessWidget {
  final DeepLinkController controller;

  const _EmptyTree({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.folder_open,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'Пусто. Создай папку или диплинк.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => createFolderIn(context, controller, null),
                  icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                  label: const Text('Папка'),
                ),
                FilledButton.icon(
                  onPressed: () => createLinkIn(context, controller, null),
                  icon: const Icon(Icons.add_link, size: 18),
                  label: const Text('Диплинк'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeRow extends StatelessWidget {
  final DeepLinkController controller;
  final TreeNode node;
  final int depth;

  const _NodeRow({
    required this.controller,
    required this.node,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = controller.selectedId == node.id;

    final row = InkWell(
      onTap: () {
        controller.select(node.id);
        if (node.isFolder && !node.expanded) controller.toggleExpanded(node.id);
      },
      onDoubleTap: node.isFolder
          ? () => controller.toggleExpanded(node.id)
          : null,
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: Container(
        height: 34,
        padding: EdgeInsets.only(left: 8.0 + depth * 16, right: 8),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.12)
              : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: node.isFolder
                  ? InkWell(
                      onTap: () => controller.toggleExpanded(node.id),
                      child: Icon(
                        node.expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_right,
                        size: 18,
                      ),
                    )
                  : null,
            ),
            Icon(
              node.isFolder
                  ? (node.expanded ? Icons.folder_open : Icons.folder)
                  : Icons.link,
              size: 18,
              color: node.isFolder
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.title,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (node.isFolder)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '${controller.countLinksIn(node.id)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final draggable = Draggable<String>(
      data: node.id,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _DragFeedback(node: node),
      childWhenDragging: Opacity(opacity: 0.4, child: row),
      child: row,
    );

    if (!node.isFolder) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: draggable,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: DragTarget<String>(
        onWillAcceptWithDetails: (details) =>
            controller.canDropInto(details.data, node.id),
        onAcceptWithDetails: (details) =>
            controller.move(details.data, node.id),
        builder: (context, candidate, _) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: candidate.isEmpty
                  ? Colors.transparent
                  : theme.colorScheme.primary,
            ),
          ),
          child: draggable,
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    controller.select(node.id);
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    final action = await showMenu<_NodeAction>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        if (node.isFolder) ...[
          const PopupMenuItem(
            value: _NodeAction.newFolder,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.create_new_folder_outlined),
              title: Text('Новая папка внутри'),
            ),
          ),
          const PopupMenuItem(
            value: _NodeAction.newLink,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.add_link),
              title: Text('Новый диплинк внутри'),
            ),
          ),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem(
          value: _NodeAction.rename,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.edit_outlined),
            title: Text('Переименовать'),
          ),
        ),
        if (node.parentId != null)
          const PopupMenuItem(
            value: _NodeAction.moveToRoot,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.drive_file_move_outline),
              title: Text('Переместить в корень'),
            ),
          ),
        const PopupMenuItem(
          value: _NodeAction.delete,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.delete_outline),
            title: Text('Удалить'),
          ),
        ),
      ],
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case _NodeAction.newFolder:
        await createFolderIn(context, controller, node.id);
      case _NodeAction.newLink:
        await createLinkIn(context, controller, node.id);
      case _NodeAction.rename:
        await renameNode(context, controller, node);
      case _NodeAction.moveToRoot:
        await controller.move(node.id, null);
      case _NodeAction.delete:
        await deleteNode(context, controller, node);
    }
  }
}

class _DragFeedback extends StatelessWidget {
  final TreeNode node;

  const _DragFeedback({required this.node});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(6),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(node.isFolder ? Icons.folder : Icons.link, size: 16),
            const SizedBox(width: 8),
            Text(node.title),
          ],
        ),
      ),
    );
  }
}

enum _NodeAction { newFolder, newLink, rename, moveToRoot, delete }

// ===================== Общие действия над узлами =====================

Future<void> createFolderIn(
  BuildContext context,
  DeepLinkController controller,
  String? parentId,
) async {
  final title = await showFolderDialog(context);
  if (title == null) return;
  await controller.createFolder(parentId: parentId, title: title);
}

Future<void> createLinkIn(
  BuildContext context,
  DeepLinkController controller,
  String? parentId,
) async {
  final result = await showLinkDialog(
    context,
    scheme: controller.selectedScheme,
  );
  if (result == null) return;

  final parsed = controller.parseLinkInput(result.link);
  await controller.createLink(
    parentId: parentId,
    title: result.title,
    description: result.description,
    rawLink: result.link,
  );

  if (!context.mounted) return;
  if (parsed.scheme != null && parsed.scheme != controller.selectedScheme) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Схема ${parsed.scheme} добавлена в список и закреплена за '
          'этим диплинком — он не зависит от активной схемы.',
        ),
      ),
    );
  }
}

Future<void> renameNode(
  BuildContext context,
  DeepLinkController controller,
  TreeNode node,
) async {
  if (node.isFolder) {
    final title = await showFolderDialog(context, initialTitle: node.title);
    if (title == null) return;
    await controller.updateNode(id: node.id, title: title);
    return;
  }

  final result = await showLinkDialog(
    context,
    scheme: node.scheme ?? controller.selectedScheme,
    initialTitle: node.title,
    initialDescription: node.description,
    initialPath: node.path,
    isEdit: true,
  );
  if (result == null) return;

  await controller.updateNode(
    id: node.id,
    title: result.title,
    description: result.description,
    rawLink: result.link,
  );
}

Future<void> deleteNode(
  BuildContext context,
  DeepLinkController controller,
  TreeNode node,
) async {
  final inside = node.isFolder ? controller.countLinksIn(node.id) : 0;
  final ok = await confirmDelete(
    context,
    title: node.isFolder ? 'Удалить папку?' : 'Удалить диплинк?',
    message: node.isFolder
        ? '«${node.title}» и всё внутри ($inside диплинков) будет удалено.'
        : '«${node.title}» будет удалён без возможности восстановления.',
  );
  if (ok) await controller.delete(node.id);
}
