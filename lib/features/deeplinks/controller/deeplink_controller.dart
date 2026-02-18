import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/deeplink_item.dart';
import '../../../data/repositories/deeplink_repository.dart';
import 'dart:convert';
import '../../../data/models/app_backup.dart';

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

    for (final item in iosItems) {
      item.iosTail ??= _extractTailGeneric(item.deepLink);
    }

    isLoading = false;
    notifyListeners();
  }

  String exportToJsonString() {
    final backup = AppBackup(
      version: 1,
      iosPrefixes: List<String>.from(iosPrefixes),
      iosSelectedPrefix: selectedIosPrefix,
      iosItems: List<DeepLinkItem>.from(iosItems),
      androidItems: List<DeepLinkItem>.from(androidItems),
    );

    return const JsonEncoder.withIndent('  ').convert(backup.toJson());
  }

  Future<void> importFromJsonString(
    String jsonString, {
    bool replace = true,
  }) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw FormatException('JSON должен быть объектом');
    }

    final backup = AppBackup.fromJson(decoded.cast<String, dynamic>());

    List<String> normalizeList(List<String> list) {
      final out = <String>[];
      for (final p in list) {
        final n = _normalizePrefix(p);
        if (n.isNotEmpty && !out.contains(n)) out.add(n);
      }
      return out.isEmpty ? <String>['example://'] : out;
    }

    final importedPrefixes = normalizeList(backup.iosPrefixes);
    final importedSelected = _normalizePrefix(backup.iosSelectedPrefix);
    final safeSelected = importedSelected.isNotEmpty
        ? importedSelected
        : importedPrefixes.first;

    if (replace) {
      iosPrefixes
        ..clear()
        ..addAll(importedPrefixes);
      selectedIosPrefix = safeSelected;

      iosItems
        ..clear()
        ..addAll(backup.iosItems);

      androidItems
        ..clear()
        ..addAll(backup.androidItems);
    } else {
      for (final p in importedPrefixes) {
        if (!iosPrefixes.contains(p)) iosPrefixes.add(p);
      }

      final existingIosIds = iosItems.map((e) => e.id).toSet();
      for (final item in backup.iosItems) {
        if (!existingIosIds.contains(item.id)) iosItems.add(item);
      }

      final existingAndroidIds = androidItems.map((e) => e.id).toSet();
      for (final item in backup.androidItems) {
        if (!existingAndroidIds.contains(item.id)) androidItems.add(item);
      }
    }

    for (final item in iosItems) {
      item.iosTail ??= _extractTailGeneric(item.deepLink);
    }

    await _repo.saveIosPrefixes(iosPrefixes);
    await _repo.saveSelectedIosPrefix(selectedIosPrefix);
    await _repo.save(true, iosItems);
    await _repo.save(false, androidItems);

    notifyListeners();
  }

  List<DeepLinkItem> itemsFor(bool isIos) => isIos ? iosItems : androidItems;

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

  String _composeWithPrefix(String prefix, String tail) {
    final p = _normalizePrefix(prefix);
    final t = tail.startsWith('/') ? tail.substring(1) : tail;
    return '$p$t';
  }

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
