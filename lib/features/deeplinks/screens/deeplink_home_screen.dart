import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../../data/repositories/deeplink_repository.dart';
import '../../../data/storage/local_storage.dart';
import '../controller/deeplink_controller.dart';
import '../widgets/detail_pane.dart';
import '../widgets/scheme_menu.dart';
import '../widgets/tree_panel.dart';

class DeepLinkHomeScreen extends StatefulWidget {
  const DeepLinkHomeScreen({super.key});

  @override
  State<DeepLinkHomeScreen> createState() => _DeepLinkHomeScreenState();
}

class _DeepLinkHomeScreenState extends State<DeepLinkHomeScreen> {
  static const _minPanelWidth = 200.0;
  static const _maxPanelWidth = 520.0;

  late final DeepLinkController _controller;
  double _panelWidth = 300;

  @override
  void initState() {
    super.initState();
    _controller = DeepLinkController(DeepLinkRepository(LocalStorage()));
    _controller.init();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _exportJson() async {
    try {
      final jsonString = _controller.exportToJsonString();

      final location = await getSaveLocation(
        suggestedName: 'deeplinks.json',
        acceptedTypeGroups: [_jsonGroup],
      );
      if (location == null) return;

      await XFile.fromData(
        utf8.encode(jsonString),
        mimeType: 'application/json',
        name: 'deeplinks.json',
      ).saveTo(location.path);

      _toast('Экспорт завершён');
    } catch (e) {
      _toast('Ошибка экспорта: $e');
    }
  }

  Future<void> _importJson() async {
    try {
      final file = await openFile(acceptedTypeGroups: [_jsonGroup]);
      if (file == null) return;

      final content = await file.readAsString();
      if (!mounted) return;

      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Импорт JSON'),
          content: const Text(
            'Заменить текущее дерево целиком или добавить импорт в корень?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Добавить'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Заменить'),
            ),
          ],
        ),
      );
      if (replace == null) return;

      await _controller.importFromJsonString(content, replace: replace);
      _toast('Импорт завершён');
    } catch (e) {
      _toast('Ошибка импорта: $e');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  static const _jsonGroup = XTypeGroup(
    label: 'JSON',
    extensions: ['json'],
    uniformTypeIdentifiers: ['public.json'],
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('DeepLink QR'),
            actions: [
              if (!_controller.isLoading) SchemeMenu(controller: _controller),
              IconButton(
                tooltip: 'Импорт JSON',
                onPressed: _controller.isLoading ? null : _importJson,
                icon: const Icon(Icons.file_upload_outlined),
              ),
              IconButton(
                tooltip: 'Экспорт JSON',
                onPressed: _controller.isLoading ? null : _exportJson,
                icon: const Icon(Icons.file_download_outlined),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Row(
                  children: [
                    SizedBox(
                      width: _panelWidth,
                      child: TreePanel(controller: _controller),
                    ),
                    _ResizeHandle(
                      onDrag: (dx) => setState(() {
                        _panelWidth = (_panelWidth + dx).clamp(
                          _minPanelWidth,
                          _maxPanelWidth,
                        );
                      }),
                    ),
                    Expanded(child: DetailPane(controller: _controller)),
                  ],
                ),
        );
      },
    );
  }
}

class _ResizeHandle extends StatelessWidget {
  final void Function(double dx) onDrag;

  const _ResizeHandle({required this.onDrag});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: const SizedBox(
          width: 8,
          child: Center(child: VerticalDivider(width: 1)),
        ),
      ),
    );
  }
}
