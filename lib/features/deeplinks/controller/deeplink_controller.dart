import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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
        ? _normalizePrefix(selected)
        : (iosPrefixes.isNotEmpty
              ? _normalizePrefix(iosPrefixes.first)
              : 'example://');

    // гарантируем, что у всех iOS есть iosTail (для массовой смены префикса)
    for (final item in iosItems) {
      item.iosTail ??= _extractTailGeneric(item.deepLink);
    }

    isLoading = false;
    notifyListeners();
  }

  List<DeepLinkItem> itemsFor(bool isIos) => isIos ? iosItems : androidItems;

  // ===================== IMPORTANT CHANGE =====================
  // iOS: deepLink сохраняем EXACTLY как ввёл пользователь.
  // iosTail сохраняем, чтобы потом менять prefix массово.
  Future<void> add({
    required bool isIos,
    required String title,
    required String description,
    required String deepLinkFull,
  }) async {
    final id = const Uuid().v4();
    final link = deepLinkFull.trim();

    if (isIos) {
      iosItems.insert(
        0,
        DeepLinkItem(
          id: id,
          title: title,
          description: description,
          deepLink: link, // <-- как ввёл
          iosTail: _extractTailGeneric(link),
        ),
      );
      await _repo.save(true, iosItems);
    } else {
      androidItems.insert(
        0,
        DeepLinkItem(
          id: id,
          title: title,
          description: description,
          deepLink: link,
        ),
      );
      await _repo.save(false, androidItems);
    }

    notifyListeners();
  }

  // iOS: при ручном редактировании deepLink сохраняем как ввёл,
  // но обновляем iosTail (чтобы массовая смена префикса работала).
  Future<void> updateDeepLink({
    required bool isIos,
    required String id,
    required String newDeepLink,
  }) async {
    final list = isIos ? iosItems : androidItems;
    final idx = list.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    final link = newDeepLink.trim();

    if (isIos) {
      list[idx].deepLink = link; // <-- как ввёл
      list[idx].iosTail = _extractTailGeneric(link);
      await _repo.save(true, iosItems);
    } else {
      list[idx].deepLink = link;
      await _repo.save(false, androidItems);
    }

    notifyListeners();
  }

  Future<void> delete({required bool isIos, required String id}) async {
    final list = isIos ? iosItems : androidItems;
    list.removeWhere((e) => e.id == id);

    await _repo.save(isIos, list);
    notifyListeners();
  }

  // ===================== iOS prefix actions =====================

  // ТОЛЬКО при смене prefix — переписываем deepLink у всех iOS записей
  Future<void> selectIosPrefix(String prefix) async {
    selectedIosPrefix = _normalizePrefix(prefix);

    for (final item in iosItems) {
      item.iosTail ??= _extractTailGeneric(item.deepLink);
      item.deepLink = _composeWithPrefix(selectedIosPrefix, item.iosTail!);
    }

    await _repo.saveSelectedIosPrefix(selectedIosPrefix);
    await _repo.save(true, iosItems);

    notifyListeners();
  }

  Future<void> addIosPrefix(String prefix) async {
    final p = _normalizePrefix(prefix);
    if (p.isEmpty) return;

    if (!iosPrefixes.contains(p)) {
      iosPrefixes.add(p);
      await _repo.saveIosPrefixes(iosPrefixes);
    }

    // можно сразу выбрать
    await selectIosPrefix(p);
  }

  Future<void> deleteSelectedIosPrefix() async {
    if (iosPrefixes.length <= 1) return;

    final current = _normalizePrefix(selectedIosPrefix);
    iosPrefixes.remove(current);

    // выберем первый оставшийся
    selectedIosPrefix = _normalizePrefix(iosPrefixes.first);

    for (final item in iosItems) {
      item.iosTail ??= _extractTailGeneric(item.deepLink);
      item.deepLink = _composeWithPrefix(selectedIosPrefix, item.iosTail!);
    }

    await _repo.saveIosPrefixes(iosPrefixes);
    await _repo.saveSelectedIosPrefix(selectedIosPrefix);
    await _repo.save(true, iosItems);

    notifyListeners();
  }

  // ===================== helpers =====================

  // собираем link = prefix + tail (без автосборки при add/edit — только при смене prefix!)
  String _composeWithPrefix(String prefix, String tail) {
    final p = _normalizePrefix(prefix);
    final t = tail.startsWith('/') ? tail.substring(1) : tail;
    return '$p$t';
  }

  // Вытаскиваем tail универсально: "scheme://tail" -> "tail"
  // если схемы нет — считаем что это уже tail
  String _extractTailGeneric(String full) {
    final f = full.trim();
    final idx = f.indexOf('://');
    if (idx == -1) return f;
    return f.substring(idx + 3);
  }

  String _normalizePrefix(String prefix) {
    final p = prefix.trim();
    if (p.isEmpty) return '';
    if (p.endsWith('://')) return p;
    if (p.endsWith(':')) return '$p//';
    return '$p://';
  }
}
