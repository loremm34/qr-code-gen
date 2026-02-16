import '../../core/constants/storage_keys.dart';
import '../models/deeplink_item.dart';
import '../storage/local_storage.dart';

class DeepLinkRepository {
  final LocalStorage _storage;

  DeepLinkRepository(this._storage);

  String _key(bool isIos) =>
      isIos ? StorageKeys.itemsIos : StorageKeys.itemsAndroid;

  Future<List<DeepLinkItem>> load(bool isIos) async {
    final list = await _storage.getJsonList(_key(isIos));
    return list.map(DeepLinkItem.fromJson).toList();
  }

  Future<void> save(bool isIos, List<DeepLinkItem> items) async {
    await _storage.setJsonList(
      _key(isIos),
      items.map((e) => e.toJson()).toList(),
    );
  }

  // ===================== NEW: iOS prefixes =====================

  Future<List<String>> loadIosPrefixes() async {
    final list = await _storage.getStringList(StorageKeys.iosPrefixes);
    if (list.isNotEmpty) return list;

    // дефолтные значения, если в хранилище пусто
    return ['example://', 'example2://'];
  }

  Future<void> saveIosPrefixes(List<String> prefixes) async {
    await _storage.setStringList(StorageKeys.iosPrefixes, prefixes);
  }

  Future<String?> loadSelectedIosPrefix() async {
    return _storage.getString(StorageKeys.iosSelectedPrefix);
  }

  Future<void> saveSelectedIosPrefix(String prefix) async {
    await _storage.setString(StorageKeys.iosSelectedPrefix, prefix);
  }
}
