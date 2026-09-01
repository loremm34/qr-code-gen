/// Работа со схемой диплинка — всё, что стоит до `://`.
class SchemeUtils {
  static const defaultScheme = 'example://';

  /// Приводит ввод пользователя к виду `example://`.
  static String normalize(String scheme) {
    var s = scheme.trim();
    if (s.isEmpty) return '';
    // Пользователь мог вставить целый линк — берём только схему.
    final sep = s.indexOf('://');
    if (sep != -1) s = s.substring(0, sep);
    while (s.endsWith(':') || s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    if (s.isEmpty) return '';
    return '$s://';
  }

  /// Отрезает схему от полного линка и возвращает хвост (`open/123?x=1`).
  static String tailOf(String full) {
    final f = full.trim();
    final sep = f.indexOf('://');
    final tail = sep == -1 ? f : f.substring(sep + 3);
    return tail.startsWith('/') ? tail.substring(1) : tail;
  }

  /// Схема из полного линка либо `null`, если её там нет.
  static String? schemeOf(String full) {
    final f = full.trim();
    final sep = f.indexOf('://');
    if (sep <= 0) return null;
    return normalize(f.substring(0, sep));
  }

  /// Склеивает активную схему и хвост.
  static String compose(String scheme, String tail) {
    final s = normalize(scheme);
    final t = tail.trim();
    return '$s${t.startsWith('/') ? t.substring(1) : t}';
  }
}
