import 'deeplink_item.dart';

class AppBackup {
  final int version;
  final List<String> iosPrefixes;
  final String iosSelectedPrefix;
  final List<DeepLinkItem> iosItems;
  final List<DeepLinkItem> androidItems;

  AppBackup({
    required this.version,
    required this.iosPrefixes,
    required this.iosSelectedPrefix,
    required this.iosItems,
    required this.androidItems,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'ios': {
      'prefixes': iosPrefixes,
      'selectedPrefix': iosSelectedPrefix,
      'items': iosItems.map((e) => e.toJson()).toList(),
    },
    'android': {'items': androidItems.map((e) => e.toJson()).toList()},
  };

  static AppBackup fromJson(Map<String, dynamic> json) {
    final v = (json['version'] as num?)?.toInt() ?? 1;

    final ios =
        (json['ios'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final android =
        (json['android'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final prefixes =
        (ios['prefixes'] as List?)?.map((e) => e.toString()).toList() ??
        <String>[];
    final selected =
        (ios['selectedPrefix'] as String?) ??
        (prefixes.isNotEmpty ? prefixes.first : 'example://');

    final iosItemsRaw = (ios['items'] as List?) ?? const [];
    final androidItemsRaw = (android['items'] as List?) ?? const [];

    return AppBackup(
      version: v,
      iosPrefixes: prefixes,
      iosSelectedPrefix: selected,
      iosItems: iosItemsRaw
          .whereType<Map>()
          .map((e) => DeepLinkItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
      androidItems: androidItemsRaw
          .whereType<Map>()
          .map((e) => DeepLinkItem.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}
