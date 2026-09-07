import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/scheme_utils.dart';
import '../../../data/models/app_backup.dart';
import '../../../data/models/tree_node.dart';
import '../../../data/repositories/deeplink_repository.dart';

/// Результат разбора пользовательского ввода диплинка.
class ParsedLinkInput {
  final String path;

  /// Схема, которую пользователь вписал в поле вместе с путём.
  /// null, если он ввёл только хвост.
  final String? scheme;

  ParsedLinkInput(this.path, this.scheme);
}

class DeepLinkController extends ChangeNotifier {
  final DeepLinkRepository _repo;

  DeepLinkController(this._repo);

  bool isLoading = true;

  final List<TreeNode> _nodes = [];
  final List<String> schemes = [];

  String selectedScheme = SchemeUtils.defaultScheme;
  String? selectedId;

  List<TreeNode> get nodes => List.unmodifiable(_nodes);

  Future<void> init() async {
    isLoading = true;
    notifyListeners();

    final state = await _repo.load();

    _nodes
      ..clear()
      ..addAll(state.nodes);

    schemes
      ..clear()
      ..addAll(_normalizeSchemeList(state.schemes));

    final stored = SchemeUtils.normalize(state.selectedScheme);
    selectedScheme = schemes.contains(stored) ? stored : schemes.first;

    isLoading = false;
    notifyListeners();
  }

  // ===================== Чтение дерева =====================

  TreeNode? nodeById(String? id) {
    if (id == null) return null;
    for (final n in _nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  TreeNode? get selectedNode => nodeById(selectedId);

  /// Дети узла: сначала папки, внутри группы — порядок добавления.
  List<TreeNode> childrenOf(String? parentId) {
    final children = _nodes.where((n) => n.parentId == parentId);
    return [
      ...children.where((n) => n.isFolder),
      ...children.where((n) => n.isLink),
    ];
  }

  /// Цепочка родителей от корня до узла (сам узел не входит).
  List<TreeNode> ancestorsOf(String id) {
    final chain = <TreeNode>[];
    var parent = nodeById(nodeById(id)?.parentId);
    while (parent != null) {
      chain.insert(0, parent);
      parent = nodeById(parent.parentId);
    }
    return chain;
  }

  /// Полный диплинк. Если за узлом закреплена своя схема — используется она,
  /// иначе — активная.
  String fullLink(TreeNode node) =>
      SchemeUtils.compose(node.scheme ?? selectedScheme, node.path);

  int countLinksIn(String folderId) {
    var total = 0;
    for (final child in childrenOf(folderId)) {
      total += child.isLink ? 1 : countLinksIn(child.id);
    }
    return total;
  }

  // ===================== Изменение дерева =====================

  Future<String> createFolder({String? parentId, required String title}) async {
    final node = TreeNode(
      id: const Uuid().v4(),
      type: NodeType.folder,
      parentId: _folderIdFor(parentId),
      title: title.trim().isEmpty ? 'Новая папка' : title.trim(),
    );
    _nodes.add(node);
    _expandAncestors(node.parentId);
    selectedId = node.id;
    await _persistNodes();
    return node.id;
  }

  Future<String> createLink({
    String? parentId,
    required String title,
    String description = '',
    required String rawLink,
  }) async {
    final parsed = parseLinkInput(rawLink);
    if (parsed.scheme != null) await registerScheme(parsed.scheme!);

    final node = TreeNode(
      id: const Uuid().v4(),
      type: NodeType.link,
      parentId: _folderIdFor(parentId),
      title: title.trim().isEmpty ? 'Без названия' : title.trim(),
      description: description.trim(),
      path: parsed.path,
      // Схему явно вписали вместе со ссылкой — закрепляем её за диплинком,
      // чтобы он не зависел от того, какая схема сейчас активна.
      scheme: parsed.scheme,
    );
    _nodes.add(node);
    _expandAncestors(node.parentId);
    selectedId = node.id;
    await _persistNodes();
    return node.id;
  }

  Future<void> updateNode({
    required String id,
    String? title,
    String? description,
    String? rawLink,
  }) async {
    final node = nodeById(id);
    if (node == null) return;

    if (title != null && title.trim().isNotEmpty) node.title = title.trim();
    if (description != null) node.description = description.trim();

    if (rawLink != null && node.isLink) {
      final parsed = parseLinkInput(rawLink);
      if (parsed.scheme != null) {
        // Схему перевписали явно — переставляем закрепление на новую.
        await registerScheme(parsed.scheme!);
        node.scheme = parsed.scheme;
      }
      // Если схему не трогали (вписали только хвост), закрепление —
      // если оно было — остаётся как есть.
      node.path = parsed.path;
    }

    await _persistNodes();
  }

  /// Переносит узел в папку [newParentId] (null — в корень).
  /// Возвращает false, если перенос невозможен.
  Future<bool> move(String id, String? newParentId) async {
    final node = nodeById(id);
    if (node == null) return false;
    if (newParentId != null && !canDropInto(id, newParentId)) return false;
    if (node.parentId == newParentId) return false;

    node.parentId = newParentId;
    _expandAncestors(newParentId);
    await _persistNodes();
    return true;
  }

  /// Можно ли бросить узел [id] в папку [targetId].
  bool canDropInto(String id, String targetId) {
    if (id == targetId) return false;
    final target = nodeById(targetId);
    if (target == null || !target.isFolder) return false;
    return !_isDescendant(targetId, id);
  }

  Future<void> delete(String id) async {
    final doomed = <String>{id, ..._descendantIds(id)};
    _nodes.removeWhere((n) => doomed.contains(n.id));
    if (doomed.contains(selectedId)) selectedId = null;
    await _persistNodes();
  }

  /// Открепляет диплинк от его собственной схемы — он снова начинает
  /// следовать за активной схемой.
  Future<void> followActiveScheme(String id) async {
    final node = nodeById(id);
    if (node == null || !node.isLink || node.scheme == null) return;
    node.scheme = null;
    await _persistNodes();
  }

  Future<void> toggleExpanded(String id) async {
    final node = nodeById(id);
    if (node == null || !node.isFolder) return;
    node.expanded = !node.expanded;
    await _persistNodes();
  }

  void select(String? id) {
    if (selectedId == id) return;
    selectedId = id;
    notifyListeners();
  }

  // ===================== Схемы =====================

  Future<void> selectScheme(String scheme) async {
    final s = SchemeUtils.normalize(scheme);
    if (s.isEmpty || s == selectedScheme) return;
    if (!schemes.contains(s)) schemes.add(s);
    selectedScheme = s;
    await _repo.saveSchemes(schemes);
    await _repo.saveSelectedScheme(selectedScheme);
    notifyListeners();
  }

  /// Добавляет схему в список, не переключаясь на неё.
  /// Возвращает true, если такой схемы ещё не было.
  Future<bool> registerScheme(String scheme) async {
    final s = SchemeUtils.normalize(scheme);
    if (s.isEmpty || schemes.contains(s)) return false;
    schemes.add(s);
    await _repo.saveSchemes(schemes);
    notifyListeners();
    return true;
  }

  Future<void> addScheme(String scheme) async {
    final s = SchemeUtils.normalize(scheme);
    if (s.isEmpty) return;
    if (!schemes.contains(s)) {
      schemes.add(s);
      await _repo.saveSchemes(schemes);
    }
    await selectScheme(s);
    notifyListeners();
  }

  Future<void> renameScheme(String from, String to) async {
    final oldScheme = SchemeUtils.normalize(from);
    final newScheme = SchemeUtils.normalize(to);
    if (newScheme.isEmpty || oldScheme == newScheme) return;

    final index = schemes.indexOf(oldScheme);
    if (index == -1) return;
    if (schemes.contains(newScheme)) {
      schemes.removeAt(index);
    } else {
      schemes[index] = newScheme;
    }
    if (selectedScheme == oldScheme) selectedScheme = newScheme;

    await _repo.saveSchemes(schemes);
    await _repo.saveSelectedScheme(selectedScheme);
    notifyListeners();
  }

  /// Удаляет схему. Последнюю удалить нельзя.
  Future<void> deleteScheme(String scheme) async {
    if (schemes.length <= 1) return;
    final s = SchemeUtils.normalize(scheme);
    if (!schemes.remove(s)) return;
    if (selectedScheme == s) selectedScheme = schemes.first;

    await _repo.saveSchemes(schemes);
    await _repo.saveSelectedScheme(selectedScheme);
    notifyListeners();
  }

  /// Делит ввод на схему и путь. Схема возвращается, только если
  /// пользователь действительно её написал.
  ParsedLinkInput parseLinkInput(String raw) =>
      ParsedLinkInput(SchemeUtils.tailOf(raw), SchemeUtils.schemeOf(raw));

  // ===================== Экспорт / импорт =====================

  String exportToJsonString() {
    final backup = AppBackup(
      version: AppBackup.currentVersion,
      schemes: List<String>.from(schemes),
      selectedScheme: selectedScheme,
      nodes: List<TreeNode>.from(_nodes),
    );
    return const JsonEncoder.withIndent('  ').convert(backup.toJson());
  }

  /// [replace] — затереть текущее дерево, иначе импорт добавится в корень.
  Future<void> importFromJsonString(
    String jsonString, {
    bool replace = true,
  }) async {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      throw const FormatException('Ожидается JSON-объект');
    }

    final backup = AppBackup.fromJson(decoded.cast<String, dynamic>());

    if (replace) {
      _nodes
        ..clear()
        ..addAll(backup.nodes);
      schemes
        ..clear()
        ..addAll(_normalizeSchemeList(backup.schemes));
      selectedScheme = schemes.contains(backup.selectedScheme)
          ? backup.selectedScheme
          : schemes.first;
      selectedId = null;
    } else {
      // Свежие id, чтобы импорт не конфликтовал с уже существующими узлами.
      final remap = <String, String>{
        for (final n in backup.nodes) n.id: const Uuid().v4(),
      };
      for (final n in backup.nodes) {
        _nodes.add(
          n.copyWith(
            id: remap[n.id],
            parentId: n.parentId == null ? null : remap[n.parentId],
          ),
        );
      }
      for (final s in backup.schemes) {
        if (!schemes.contains(s)) schemes.add(s);
      }
    }

    await _repo.saveAll(
      DeepLinkState(
        nodes: _nodes,
        schemes: schemes,
        selectedScheme: selectedScheme,
      ),
    );
    notifyListeners();
  }

  // ===================== Внутреннее =====================

  /// Куда класть новый узел: в саму папку либо рядом с диплинком.
  String? _folderIdFor(String? anchorId) {
    final anchor = nodeById(anchorId);
    if (anchor == null) return null;
    return anchor.isFolder ? anchor.id : anchor.parentId;
  }

  void _expandAncestors(String? parentId) {
    var current = nodeById(parentId);
    while (current != null) {
      current.expanded = true;
      current = nodeById(current.parentId);
    }
  }

  Set<String> _descendantIds(String id) {
    final out = <String>{};
    for (final child in _nodes.where((n) => n.parentId == id)) {
      out
        ..add(child.id)
        ..addAll(_descendantIds(child.id));
    }
    return out;
  }

  bool _isDescendant(String candidateId, String ancestorId) {
    var current = nodeById(nodeById(candidateId)?.parentId);
    while (current != null) {
      if (current.id == ancestorId) return true;
      current = nodeById(current.parentId);
    }
    return false;
  }

  List<String> _normalizeSchemeList(Iterable<String> raw) {
    final out = <String>[];
    for (final s in raw) {
      final n = SchemeUtils.normalize(s);
      if (n.isNotEmpty && !out.contains(n)) out.add(n);
    }
    return out.isEmpty ? [SchemeUtils.defaultScheme] : out;
  }

  Future<void> _persistNodes() async {
    await _repo.saveNodes(_nodes);
    notifyListeners();
  }
}
