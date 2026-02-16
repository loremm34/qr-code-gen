class DeepLinkItem {
  final String id;
  String title;
  String description;
  String deepLink;

  DeepLinkItem({
    required this.id,
    required this.title,
    required this.description,
    required this.deepLink,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'deepLink': deepLink,
  };

  static DeepLinkItem fromJson(Map<String, dynamic> json) {
    return DeepLinkItem(
      id: json['id'] as String,
      title: json['title'] as String,
      description: (json['description'] as String?) ?? '',
      deepLink: json['deepLink'] as String,
    );
  }
}
