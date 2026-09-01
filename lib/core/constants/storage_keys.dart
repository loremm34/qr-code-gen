class StorageKeys {
  /// Дерево папок и диплинков (плоский список с parentId).
  static const nodes = 'tree_nodes';

  /// Список схем (всё, что до `://`).
  static const schemes = 'schemes';

  /// Активная схема.
  static const selectedScheme = 'selected_scheme';

  // ===== Ключи старой версии, читаются один раз при миграции. =====
  static const legacyItemsIos = 'items_ios';
  static const legacyItemsAndroid = 'items_android';
  static const legacyIosPrefixes = 'ios_prefixes';
  static const legacyIosSelectedPrefix = 'ios_selected_prefix';
}
