import 'package:uuid/uuid.dart';

import '../../core/utils/scheme_utils.dart';
import 'tree_node.dart';

/// Снимок всего состояния приложения для экспорта/импорта в JSON.
///
/// В файл дерево пишется вложенным (так его удобно читать глазами),
/// внутри приложения оно живёт плоским списком с `parentId`.
class AppBackup {
  static const currentVersion = 2;

  final int version;
  final List<String> schemes;
  final String selectedScheme;

  /// Плоский список узлов.
  final List<TreeNode> nodes;

  AppBackup({
    required this.version,
    required this.schemes,
    required this.selectedScheme,
    required this.nodes,
  });

  Map<String, dynamic> toJson() => {
    'version': currentVersion,
    'schemes': schemes,
    'selectedScheme': selectedScheme,
    'root': _nest(null),
  };

  List<Map<String, dynamic>> _nest(String? parentId) {
    final children = nodes.where((n) => n.parentId == parentId);
    return [
      for (final n in children)
        if (n.isFolder)
          {
            'id': n.id,
            'type': 'folder',
            'title': n.title,
            'description': n.description,
            'expanded': n.expanded,
            'children': _nest(n.id),
          }
        else
          {
            'id': n.id,
            'type': 'link',
            'title': n.title,
            'description': n.description,
            'path': n.path,
          },
    ];
  }

  static AppBackup fromJson(Map<String, dynamic> json) {
    final version = (json['version'] as num?)?.toInt() ?? 1;
    if (version >= 2 || json.containsKey('root')) return _parseV2(json);
    return _parseV1(json);
  }

  static AppBackup _parseV2(Map<String, dynamic> json) {
    final schemes = _normalizedSchemes(
      (json['schemes'] as List?)?.map((e) => e.toString()) ?? const [],
    );

    final nodes = <TreeNode>[];
    void walk(List<dynamic> raw, String? parentId) {
      for (final entry in raw.whereType<Map>()) {
        final map = entry.cast<String, dynamic>();
        final isFolder = (map['type'] as String?) == 'folder';
        final node = TreeNode(
          id: (map['id'] as String?) ?? const Uuid().v4(),
          type: isFolder ? NodeType.folder : NodeType.link,
          parentId: parentId,
          title: (map['title'] as String?) ?? '',
          description: (map['description'] as String?) ?? '',
          path: isFolder ? '' : SchemeUtils.tailOf((map['path'] as String?) ?? ''),
          expanded: (map['expanded'] as bool?) ?? true,
        );
        nodes.add(node);
        if (isFolder) walk((map['children'] as List?) ?? const [], node.id);
      }
    }

    walk((json['root'] as List?) ?? const [], null);

    return AppBackup(
      version: currentVersion,
      schemes: schemes,
      selectedScheme: _pickSelected(json['selectedScheme'], schemes),
      nodes: nodes,
    );
  }

  /// Формат до отказа от разделения на iOS/Android: все записи
  /// переезжают в корень, префиксы становятся схемами.
  static AppBackup _parseV1(Map<String, dynamic> json) {
    final ios = (json['ios'] as Map?)?.cast<String, dynamic>() ?? const {};
    final android =
        (json['android'] as Map?)?.cast<String, dynamic>() ?? const {};

    final rawItems = <Map<String, dynamic>>[
      ...((ios['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>()),
      ...((android['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>()),
    ];

    final nodes = <TreeNode>[
      for (final item in rawItems)
        TreeNode(
          id: (item['id'] as String?) ?? const Uuid().v4(),
          type: NodeType.link,
          title: (item['title'] as String?) ?? 'Без названия',
          description: (item['description'] as String?) ?? '',
          path: SchemeUtils.tailOf(
            (item['iosTail'] as String?) ?? (item['deepLink'] as String?) ?? '',
          ),
        ),
    ];

    final schemes = _normalizedSchemes([
      ...((ios['prefixes'] as List?) ?? const []).map((e) => e.toString()),
      for (final item in rawItems)
        SchemeUtils.schemeOf((item['deepLink'] as String?) ?? '') ?? '',
    ]);

    return AppBackup(
      version: currentVersion,
      schemes: schemes,
      selectedScheme: _pickSelected(ios['selectedPrefix'], schemes),
      nodes: nodes,
    );
  }

  static List<String> _normalizedSchemes(Iterable<String> raw) {
    final out = <String>[];
    for (final s in raw) {
      final n = SchemeUtils.normalize(s);
      if (n.isNotEmpty && !out.contains(n)) out.add(n);
    }
    return out.isEmpty ? [SchemeUtils.defaultScheme] : out;
  }

  static String _pickSelected(Object? raw, List<String> schemes) {
    final selected = SchemeUtils.normalize(raw is String ? raw : '');
    if (selected.isNotEmpty && schemes.contains(selected)) return selected;
    return schemes.first;
  }
}
