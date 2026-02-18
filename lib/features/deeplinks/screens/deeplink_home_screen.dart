import 'package:flutter/material.dart';

import '../../../data/repositories/deeplink_repository.dart';
import '../../../data/storage/local_storage.dart';
import '../controller/deeplink_controller.dart';
import '../widgets/add_deeplink_dialog.dart';
import '../widgets/deeplink_list.dart';
import '../widgets/ios_prefix_menu.dart';
import 'dart:convert';
import 'package:file_selector/file_selector.dart';

class DeepLinkHomeScreen extends StatefulWidget {
  const DeepLinkHomeScreen({super.key});

  @override
  State<DeepLinkHomeScreen> createState() => _DeepLinkHomeScreenState();
}

class _DeepLinkHomeScreenState extends State<DeepLinkHomeScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final DeepLinkController _controller;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _controller = DeepLinkController(DeepLinkRepository(LocalStorage()));

    _controller.init();
  }

  bool get _isIos => _tabController.index == 0;

  Future<void> _onAddPressed() async {
    final result = await showDialog<AddDialogResult>(
      context: context,
      builder: (_) => const AddDeepLinkDialog(),
    );

    if (result == null) return;

    await _controller.add(
      isIos: _isIos,
      title: result.title.trim(),
      description: result.description.trim(),
      deepLinkFull: result.deepLink.trim(),
    );
  }

  Future<void> _exportJsonToFile() async {
    try {
      final jsonString = _controller.exportToJsonString();

      final location = await getSaveLocation(
        suggestedName: 'deeplinks_backup.json',
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'JSON',
            extensions: ['json'],
            mimeTypes: ['application/json'],
          ),
        ],
      );

      if (location == null) return;

      final file = XFile.fromData(
        utf8.encode(jsonString),
        mimeType: 'application/json',
        name: 'deeplinks_backup.json',
      );

      await file.saveTo(location.path);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Экспорт завершён')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка экспорта: $e')));
      }
    }
  }

  Future<void> _importJsonFromFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(
            label: 'JSON',
            extensions: ['json'],
            mimeTypes: ['application/json'],
          ),
        ],
      );

      if (file == null) return;

      final content = await file.readAsString();

      final replace = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Импорт JSON'),
          content: const Text(
            'Заменить текущие данные или добавить к текущим?',
          ),
          actions: [
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

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Импорт завершён')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка импорта: $e')));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('DeepLink QR Tracker'),
            bottom: TabBar(
              controller: _tabController,
              onTap: (_) => setState(() {}),
              tabs: const [
                Tab(text: 'iOS'),
                Tab(text: 'Android'),
              ],
            ),
            actions: [
              IconButton(
                tooltip: 'Импорт JSON',
                onPressed: _controller.isLoading ? null : _importJsonFromFile,
                icon: const Icon(Icons.file_open),
              ),
              IconButton(
                tooltip: 'Экспорт JSON',
                onPressed: _controller.isLoading ? null : _exportJsonToFile,
                icon: const Icon(Icons.download),
              ),

              if (_tabController.index == 0) ...[
                IosPrefixMenu(controller: _controller),

                IconButton(
                  tooltip: 'Удалить текущий prefix',
                  onPressed:
                      (_controller.iosPrefixes.length <= 1 ||
                          _controller.isLoading)
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Удалить prefix?'),
                              content: Text(
                                'Удалить "${_controller.selectedIosPrefix}"?\n'
                                'После удаления будет выбран следующий prefix, и у всех iOS диплинков сменится prefix.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Отмена'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Удалить'),
                                ),
                              ],
                            ),
                          );

                          if (ok == true) {
                            await _controller.deleteSelectedIosPrefix();
                          }
                        },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],

              IconButton(
                tooltip: 'Добавить',
                onPressed: _controller.isLoading ? null : _onAddPressed,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: _controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    DeepLinkList(
                      items: _controller.iosItems,
                      onEditLink: (id, newLink) => _controller.updateDeepLink(
                        isIos: true,
                        id: id,
                        newDeepLink: newLink,
                      ),
                      onDelete: (id) => _controller.delete(isIos: true, id: id),
                    ),
                    DeepLinkList(
                      items: _controller.androidItems,
                      onEditLink: (id, newLink) => _controller.updateDeepLink(
                        isIos: false,
                        id: id,
                        newDeepLink: newLink,
                      ),
                      onDelete: (id) =>
                          _controller.delete(isIos: false, id: id),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _controller.isLoading ? null : _onAddPressed,
            icon: const Icon(Icons.add),
            label: Text(_isIos ? 'Добавить (iOS)' : 'Добавить (Android)'),
          ),
        );
      },
    );
  }
}
