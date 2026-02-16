class DeepLinkItem {
  final String id;
  String title;
  String description;

  String deepLink;

  String? iosTail;

  DeepLinkItem({
    required this.id,
    required this.title,
    required this.description,
    required this.deepLink,
    this.iosTail,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'deepLink': deepLink,
    'iosTail': iosTail,
  };

  static DeepLinkItem fromJson(Map<String, dynamic> json) => DeepLinkItem(
    id: json['id'] as String,
    title: json['title'] as String,
    description: (json['description'] as String?) ?? '',
    deepLink: json['deepLink'] as String,
    iosTail: json['iosTail'] as String?,
  );
}
