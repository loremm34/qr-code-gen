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
        ? selected
        : (iosPrefixes.isNotEmpty ? iosPrefixes.first : 'example://');

    // важное: если старые iOS items без iosTail — попробуем восстановить
    _ensureIosTails();

    isLoading = false;
    notifyListeners();
  }

  void _ensureIosTails() {
    for (final item in iosItems) {
      item.iosTail ??= _extractTailFromFull(item.deepLink, selectedIosPrefix);
      // гарантируем что deepLink соответствует выбранному prefix
      item.deepLink = _composeFull(selectedIosPrefix, item.iosTail!);
    }
    // не сохраняем тут автоматически, чтобы не плодить записи на init; сохранится при первом действии
  }

  Future<void> add({
    required bool isIos,
    required String title,
    required String description,
    required String deepLinkFull, // NEW: вводишь полностью
  }) async {
    final id = const Uuid().v4();

    if (isIos) {
      final tail = _extractTailFromFull(deepLinkFull, selectedIosPrefix);
      final full = _composeFull(selectedIosPrefix, tail);

      iosItems.insert(
        0,
        DeepLinkItem(
          id: id,
          title: title,
          description: description,
          deepLink: full,
          iosTail: tail,
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
          deepLink: deepLinkFull, // Android: как ввёл, так и есть
        ),
      );

      await _repo.save(false, androidItems);
    }

    notifyListeners();
  }

  Future<void> updateDeepLink({
    required bool isIos,
    required String id,
    required String newDeepLink,
  }) async {
    final list = isIos ? iosItems : androidItems;
    final idx = list.indexWhere((e) => e.id == id);
    if (idx == -1) return;

    if (isIos) {
      // сохраняем tail и пересобираем full по текущему prefix
      final tail = _extractTailFromFull(newDeepLink, selectedIosPrefix);
      list[idx].iosTail = tail;
      list[idx].deepLink = _composeFull(selectedIosPrefix, tail);
      await _repo.save(true, iosItems);
    } else {
      list[idx].deepLink = newDeepLink;
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

  Future<void> selectIosPrefix(String prefix) async {
    selectedIosPrefix = _normalizePrefix(prefix);

    // ВОТ ТВОЁ ТРЕБОВАНИЕ: меняем prefix у ВСЕХ iOS диплинков
    for (final item in iosItems) {
      item.iosTail ??= _extractTailFromFull(item.deepLink, selectedIosPrefix);
      item.deepLink = _composeFull(selectedIosPrefix, item.iosTail!);
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
    await selectIosPrefix(p);
  }

  Future<void> deleteIosPrefix(String prefix) async {
    if (iosPrefixes.length <= 1) return;
    final p = _normalizePrefix(prefix);

    iosPrefixes.remove(p);

    if (selectedIosPrefix == p) {
      selectedIosPrefix = iosPrefixes.first;
      await _repo.saveSelectedIosPrefix(selectedIosPrefix);

      for (final item in iosItems) {
        item.iosTail ??= _extractTailFromFull(item.deepLink, selectedIosPrefix);
        item.deepLink = _composeFull(selectedIosPrefix, item.iosTail!);
      }
      await _repo.save(true, iosItems);
    }

    await _repo.saveIosPrefixes(iosPrefixes);
    notifyListeners();
  }

  // ===================== helpers =====================

  String _composeFull(String prefix, String tail) {
    final p = _normalizePrefix(prefix);
    final t = tail.startsWith('/') ? tail.substring(1) : tail;
    return '$p$t';
  }

  String _extractTailFromFull(String full, String currentPrefix) {
    final f = full.trim();

    // 1) Если начинается с текущего prefix — просто отрезаем его
    final p = _normalizePrefix(currentPrefix);
    if (f.startsWith(p)) {
      return f.substring(p.length);
    }

    // 2) Fallback: отрежем "scheme://"
    final idx = f.indexOf('://');
    if (idx != -1) {
      return f.substring(idx + 3);
    }

    return f;
  }

  String _normalizePrefix(String prefix) {
    final p = prefix.trim();
    if (p.isEmpty) return '';
    if (p.endsWith('://')) return p;
    if (p.endsWith(':')) return '$p//';
    return '$p://';
  }
}
