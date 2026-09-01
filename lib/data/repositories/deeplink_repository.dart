import '../../core/constants/storage_keys.dart';
import '../models/app_backup.dart';
import '../models/tree_node.dart';
import '../storage/local_storage.dart';

/// Состояние, прочитанное из локального хранилища.
class DeepLinkState {
  final List<TreeNode> nodes;
  final List<String> schemes;
  final String selectedScheme;

  DeepLinkState({
    required this.nodes,
    required this.schemes,
    required this.selectedScheme,
  });
}

class DeepLinkRepository {
  final LocalStorage _storage;

  DeepLinkRepository(this._storage);

  Future<DeepLinkState> load() async {
    final raw = await _storage.getJsonList(StorageKeys.nodes);

    if (raw.isEmpty && !await _storage.contains(StorageKeys.nodes)) {
      final migrated = await _migrateLegacy();
      if (migrated != null) return migrated;
    }

    final schemes = await _storage.getStringList(StorageKeys.schemes);
    final selected = await _storage.getString(StorageKeys.selectedScheme);

    return DeepLinkState(
      nodes: raw.map(TreeNode.fromJson).toList(),
      schemes: schemes,
      selectedScheme: selected ?? '',
    );
  }

  Future<void> saveNodes(List<TreeNode> nodes) =>
      _storage.setJsonList(StorageKeys.nodes, [
        for (final n in nodes) n.toJson(),
      ]);

  Future<void> saveSchemes(List<String> schemes) =>
      _storage.setStringList(StorageKeys.schemes, schemes);

  Future<void> saveSelectedScheme(String scheme) =>
      _storage.setString(StorageKeys.selectedScheme, scheme);

  Future<void> saveAll(DeepLinkState state) async {
    await saveNodes(state.nodes);
    await saveSchemes(state.schemes);
    await saveSelectedScheme(state.selectedScheme);
  }

  /// Разовый перенос данных из версии с вкладками iOS/Android.
  Future<DeepLinkState?> _migrateLegacy() async {
    final ios = await _storage.getJsonList(StorageKeys.legacyItemsIos);
    final android = await _storage.getJsonList(StorageKeys.legacyItemsAndroid);
    final prefixes = await _storage.getStringList(
      StorageKeys.legacyIosPrefixes,
    );
    if (ios.isEmpty && android.isEmpty && prefixes.isEmpty) return null;

    final backup = AppBackup.fromJson({
      'version': 1,
      'ios': {
        'prefixes': prefixes,
        'selectedPrefix':
            await _storage.getString(StorageKeys.legacyIosSelectedPrefix) ?? '',
        'items': ios,
      },
      'android': {'items': android},
    });

    final state = DeepLinkState(
      nodes: backup.nodes,
      schemes: backup.schemes,
      selectedScheme: backup.selectedScheme,
    );
    await saveAll(state);
    return state;
  }
}
