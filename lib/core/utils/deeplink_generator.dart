class DeepLinkGenerator {
  static String generate({
    required String id,
    required bool isIos,
    String? iosPrefix, // NEW
  }) {
    if (isIos) {
      final prefix = (iosPrefix == null || iosPrefix.trim().isEmpty)
          ? 'example://'
          : iosPrefix.trim();
      return '${_ensureEndsWithSchemeSeparator(prefix)}open/$id';
    } else {
      return 'myapp://open/$id?platform=android';
    }
  }

  static String _ensureEndsWithSchemeSeparator(String prefix) {
    // хотим формат типа "example://"
    if (prefix.endsWith('://')) return prefix;
    if (prefix.endsWith(':')) return '$prefix//';
    return '$prefix://';
  }
}
