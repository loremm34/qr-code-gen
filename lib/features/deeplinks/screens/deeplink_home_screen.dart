import 'package:flutter/material.dart';

import '../../../data/repositories/deeplink_repository.dart';
import '../../../data/storage/local_storage.dart';
import '../controller/deeplink_controller.dart';
import '../widgets/add_deeplink_dialog.dart';
import '../widgets/deeplink_list.dart';
import '../widgets/ios_prefix_menu.dart';

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
    if (result.title.trim().isEmpty) return;

    await _controller.add(
      isIos: _isIos,
      title: result.title.trim(),
      description: result.description.trim(),
    );
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
              if (_tabController.index == 0)
                IosPrefixMenu(controller: _controller),

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
