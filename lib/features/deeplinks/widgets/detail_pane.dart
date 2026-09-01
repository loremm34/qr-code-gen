import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../data/models/tree_node.dart';
import '../controller/deeplink_controller.dart';
import 'tree_panel.dart';

/// Правая часть окна: содержимое выбранной папки либо карточка диплинка.
class DetailPane extends StatelessWidget {
  final DeepLinkController controller;

  const DetailPane({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final node = controller.selectedNode;

    if (node == null) {
      return _RootView(controller: controller);
    }
    if (node.isFolder) {
      return _FolderView(controller: controller, folder: node);
    }
    return _LinkView(controller: controller, node: node);
  }
}

class _Breadcrumbs extends StatelessWidget {
  final DeepLinkController controller;
  final TreeNode? node;

  const _Breadcrumbs({required this.controller, this.node});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    final chain = node == null ? <TreeNode>[] : controller.ancestorsOf(node!.id);

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InkWell(
          onTap: () => controller.select(null),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text('Корень', style: style),
          ),
        ),
        for (final parent in chain) ...[
          Text('/', style: style),
          InkWell(
            onTap: () => controller.select(parent.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(parent.title, style: style),
            ),
          ),
        ],
        if (node != null) ...[
          Text('/', style: style),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              node!.title,
              style: style?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }
}

class _RootView extends StatelessWidget {
  final DeepLinkController controller;

  const _RootView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final children = controller.childrenOf(null);

    if (children.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_2,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Создай папку или диплинк слева',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    return _ChildrenGrid(
      controller: controller,
      parentId: null,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Breadcrumbs(controller: controller),
            const SizedBox(height: 6),
            Text('Корень', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

class _FolderView extends StatelessWidget {
  final DeepLinkController controller;
  final TreeNode folder;

  const _FolderView({required this.controller, required this.folder});

  @override
  Widget build(BuildContext context) {
    return _ChildrenGrid(
      controller: controller,
      parentId: folder.id,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Breadcrumbs(controller: controller, node: folder),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    folder.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Новая папка внутри',
                  icon: const Icon(Icons.create_new_folder_outlined),
                  onPressed: () =>
                      createFolderIn(context, controller, folder.id),
                ),
                IconButton(
                  tooltip: 'Новый диплинк внутри',
                  icon: const Icon(Icons.add_link),
                  onPressed: () => createLinkIn(context, controller, folder.id),
                ),
                IconButton(
                  tooltip: 'Переименовать',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => renameNode(context, controller, folder),
                ),
                IconButton(
                  tooltip: 'Удалить папку',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => deleteNode(context, controller, folder),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChildrenGrid extends StatelessWidget {
  final DeepLinkController controller;
  final String? parentId;
  final Widget header;

  const _ChildrenGrid({
    required this.controller,
    required this.parentId,
    required this.header,
  });

  @override
  Widget build(BuildContext context) {
    final children = controller.childrenOf(parentId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const Divider(height: 1),
        Expanded(
          child: children.isEmpty
              ? Center(
                  child: Text(
                    'Папка пуста',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(24),
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 280,
                        mainAxisExtent: 250,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                  itemCount: children.length,
                  itemBuilder: (context, i) => _ChildCard(
                    controller: controller,
                    node: children[i],
                  ),
                ),
        ),
      ],
    );
  }
}

class _ChildCard extends StatelessWidget {
  final DeepLinkController controller;
  final TreeNode node;

  const _ChildCard({required this.controller, required this.node});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => controller.select(node.id),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    node.isFolder ? Icons.folder : Icons.link,
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
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: node.isFolder
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.folder,
                              size: 64,
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${controller.countLinksIn(node.id)} диплинков',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        )
                      : _Qr(data: controller.fullLink(node), size: 120),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                node.isFolder
                    ? (node.description.isEmpty ? 'Папка' : node.description)
                    : controller.fullLink(node),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkView extends StatelessWidget {
  final DeepLinkController controller;
  final TreeNode node;

  const _LinkView({required this.controller, required this.node});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final link = controller.fullLink(node);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _Breadcrumbs(controller: controller, node: node),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Text(node.title, style: theme.textTheme.headlineSmall),
            ),
            IconButton(
              tooltip: 'Редактировать',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => renameNode(context, controller, node),
            ),
            IconButton(
              tooltip: 'Удалить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => deleteNode(context, controller, node),
            ),
          ],
        ),
        if (node.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(node.description, style: theme.textTheme.bodyMedium),
        ],
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    link,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Скопировать',
                  icon: const Icon(Icons.copy_all_outlined),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Диплинк скопирован')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(child: _Qr(data: link, size: 280)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Активная схема: ${controller.selectedScheme}',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// QR всегда на белом фоне — иначе камеры не читают его в тёмной теме.
class _Qr extends StatelessWidget {
  final String data;
  final double size;

  const _Qr({required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: QrImageView(
        data: data.isEmpty ? ' ' : data,
        size: size,
        backgroundColor: Colors.white,
      ),
    );
  }
}
