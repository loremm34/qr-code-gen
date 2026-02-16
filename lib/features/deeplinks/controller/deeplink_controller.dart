import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/deeplink_generator.dart';
import '../../../data/models/deeplink_item.dart';
import '../../../data/repositories/deeplink_repository.dart';

class DeepLinkController extends ChangeNotifier {
  final DeepLinkRepository _repo;

  DeepLinkController(this._repo);

  bool isLoading = true;

  final List<DeepLinkItem> iosItems = [];
  final List<DeepLinkItem> androidItems = [];

  final List<String> iosPrefixes = [];
  String selectedIosPrefix = 'example://';

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    final ios = await _repo.load(true);
    final android = await _repo.load(false);

    final prefixes = await _repo.loadIosPrefixes();
    final selected = await _repo.loadSelectedIosPrefix();

    iosItems
      ..clear()
      ..addAll(ios);
    androidItems
      ..clear()
      ..addAll(android);

    iosPrefixes
      ..clear()
      ..addAll(prefixes);

    selectedIosPrefix = (selected != null && selected.isNotEmpty)
        ? selected
        : (iosPrefixes.isNotEmpty ? iosPrefixes.first : 'example://');

    isLoading = false;
    notifyListeners();
  }

  List<DeepLinkItem> itemsFor(bool isIos) => isIos ? iosItems : androidItems;

  Future<void> add({
    required bool isIos,
    required String title,
    required String description,
  }) async {
    final id = const Uuid().v4();

    final deepLink = DeepLinkGenerator.generate(
      id: id,
      isIos: isIos,
      iosPrefix: isIos ? selectedIosPrefix : null,
    );

    itemsFor(isIos).insert(
      0,
      DeepLinkItem(
        id: id,
        title: title,
        description: description,
        deepLink: deepLink,
      ),
    );

    await _repo.save(isIos, itemsFor(isIos));
    notifyListeners();
  }

  Future<void> updateDeepLink({
    required bool isIos,
    required String id,
    required String newDeepLink,
  }) async {
    final list = itemsFor(isIos);
    final idx = list.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    list[idx].deepLink = newDeepLink;

    await _repo.save(isIos, list);
    notifyListeners();
  }

  Future<void> delete({required bool isIos, required String id}) async {
    final list = itemsFor(isIos);
    list.removeWhere((e) => e.id == id);

    await _repo.save(isIos, list);
    notifyListeners();
  }

  Future<void> selectIosPrefix(String prefix) async {
    selectedIosPrefix = prefix;
    await _repo.saveSelectedIosPrefix(prefix);
    notifyListeners();
  }

  Future<void> addIosPrefix(String prefix) async {
    final p = prefix.trim();
    if (p.isEmpty) return;
    if (iosPrefixes.contains(p)) {
      // уже есть — просто выбрать
      await selectIosPrefix(p);
      return;
    }

    iosPrefixes.add(p);
    await _repo.saveIosPrefixes(iosPrefixes);
    await selectIosPrefix(p);
  }

  Future<void> deleteIosPrefix(String prefix) async {
    if (iosPrefixes.length <= 1) return;
    iosPrefixes.remove(prefix);

    if (selectedIosPrefix == prefix) {
      selectedIosPrefix = iosPrefixes.first;
      await _repo.saveSelectedIosPrefix(selectedIosPrefix);
    }

    await _repo.saveIosPrefixes(iosPrefixes);
    notifyListeners();
  }
}
