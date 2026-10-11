import 'dart:convert';

enum StorageFailure { quota, unavailable, blocked, conflict, corrupt, unknown }

class CollectionStorageException implements Exception {
  final StorageFailure reason;
  final String details;
  const CollectionStorageException(this.reason, this.details);
  @override
  String toString() => 'CollectionStorageException($reason): $details';
}

class CollectionSnapshot {
  final int revision;
  final Map<String, String> records;
  CollectionSnapshot({
    required this.revision,
    required Map<String, String> records,
  }) : records = Map.unmodifiable(records);

  Map<String, Object> get manifest => {
    'schema': 1,
    'revision': revision,
    'keys': records.keys.toList(),
  };

  factory CollectionSnapshot.fromManifest(
    Object? data,
    Map<String, String> records,
  ) {
    if (data is! Map ||
        data['schema'] != 1 ||
        data['revision'] is! int ||
        (data['revision'] as int) < 1 ||
        data['keys'] is! List) {
      throw const CollectionStorageException(
        StorageFailure.corrupt,
        'Invalid collection manifest',
      );
    }
    final ordered = <String, String>{};
    for (final key in data['keys'] as List) {
      if (key is! String ||
          !records.containsKey(key) ||
          ordered.containsKey(key)) {
        throw const CollectionStorageException(
          StorageFailure.corrupt,
          'Missing or duplicated collection record',
        );
      }
      ordered[key] = records[key]!;
    }
    if (ordered.length != records.length) {
      throw const CollectionStorageException(
        StorageFailure.corrupt,
        'Unexpected collection records',
      );
    }
    return CollectionSnapshot(
      revision: data['revision'] as int,
      records: ordered,
    );
  }

  String encode() => jsonEncode({'manifest': manifest, 'records': records});
  factory CollectionSnapshot.decode(String value) {
    final decoded = jsonDecode(value) as Map<String, dynamic>;
    return CollectionSnapshot.fromManifest(
      decoded['manifest'],
      Map<String, String>.from(decoded['records'] as Map),
    );
  }
}

class StorageStatus {
  final String name;
  final int? usageBytes;
  final int? quotaBytes;
  final bool? persistent;
  const StorageStatus({
    required this.name,
    this.usageBytes,
    this.quotaBytes,
    this.persistent,
  });
}

abstract interface class CollectionBackend {
  Future<CollectionSnapshot?> read();
  Future<void> write(
    CollectionSnapshot snapshot, {
    required int? expectedRevision,
  });
  Future<StorageStatus> status();
  Future<bool> requestPersistence();
  void close();
}

String storageErrorMessage(Object error) {
  if (error is CollectionStorageException) {
    switch (error.reason) {
      case StorageFailure.quota:
        return 'Недостатньо місця для збереження. Попередні дерева залишилися. Спробуй фото меншого розміру або звільни місце на пристрої.';
      case StorageFailure.conflict:
        return 'Колекцію змінено в іншій вкладці. Дані оновлено; повтори збереження.';
      case StorageFailure.blocked:
        return 'Закрий інші вкладки Derevarium і повтори спробу.';
      case StorageFailure.unavailable:
        return 'Браузер не дозволяє відкрити сховище. Перевір його налаштування та повтори спробу.';
      case StorageFailure.corrupt:
        return 'Не вдалося прочитати колекцію. Дані не змінено. Можна відновити їх із копії.';
      case StorageFailure.unknown:
        break;
    }
  }
  return 'Не вдалося зберегти зміни. Попередні дерева залишилися; повтори спробу.';
}
