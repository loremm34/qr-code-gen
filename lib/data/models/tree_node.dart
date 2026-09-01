enum NodeType { folder, link }

/// Узел «файловой системы»: папка или диплинк.
///
/// Хранится плоским списком — иерархию задаёт [parentId]
/// (`null` означает корень).
class TreeNode {
  final String id;
  final NodeType type;

  String? parentId;
  String title;
  String description;

  /// Хвост диплинка после `://`. Для папок всегда пустой.
  String path;

  /// Раскрыта ли папка в дереве.
  bool expanded;

  TreeNode({
    required this.id,
    required this.type,
    this.parentId,
    this.title = '',
    this.description = '',
    this.path = '',
    this.expanded = true,
  });

  bool get isFolder => type == NodeType.folder;
  bool get isLink => type == NodeType.link;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'parentId': parentId,
    'title': title,
    'description': description,
    'path': path,
    'expanded': expanded,
  };

  static TreeNode fromJson(Map<String, dynamic> json) => TreeNode(
    id: json['id'] as String,
    type: (json['type'] as String?) == NodeType.folder.name
        ? NodeType.folder
        : NodeType.link,
    parentId: json['parentId'] as String?,
    title: (json['title'] as String?) ?? '',
    description: (json['description'] as String?) ?? '',
    path: (json['path'] as String?) ?? '',
    expanded: (json['expanded'] as bool?) ?? true,
  );

  TreeNode copyWith({String? id, String? parentId}) => TreeNode(
    id: id ?? this.id,
    type: type,
    parentId: parentId ?? this.parentId,
    title: title,
    description: description,
    path: path,
    expanded: expanded,
  );
}
