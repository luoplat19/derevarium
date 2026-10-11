import 'package:shared_preferences/shared_preferences.dart';

import 'storage_backend.dart';

CollectionBackend createCollectionBackend({required String databaseName}) =>
    PreferencesCollectionBackend(databaseName);

class PreferencesCollectionBackend implements CollectionBackend {
  final String databaseName;
  PreferencesCollectionBackend(this.databaseName);
  String get key => '${databaseName}_v1';

  @override
  Future<CollectionSnapshot?> read() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final value = prefs.getString(key);
    return value == null ? null : CollectionSnapshot.decode(value);
  }

  @override
  Future<void> write(
    CollectionSnapshot snapshot, {
    required int? expectedRevision,
  }) async {
    final current = await read();
    if (current?.revision != expectedRevision) {
      throw const CollectionStorageException(
        StorageFailure.conflict,
        'Collection changed',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    try {
      if (!await prefs.setString(key, snapshot.encode())) {
        throw StateError('Storage rejected the write');
      }
    } catch (_) {
      try {
        await prefs.reload();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<StorageStatus> status() async =>
      const StorageStatus(name: 'Локальне сховище пристрою');
  @override
  Future<bool> requestPersistence() async => false;
  @override
  void close() {}
}
