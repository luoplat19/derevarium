import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'storage_backend.dart';

CollectionBackend createCollectionBackend({required String databaseName}) =>
    IndexedDbCollectionBackend(databaseName);

class IndexedDbCollectionBackend implements CollectionBackend {
  static const _recordsStore = 'trees';
  static const _metadataStore = 'metadata';
  final String databaseName;
  web.IDBDatabase? _db;
  Future<web.IDBDatabase>? _opening;
  Map<String, String> _cached = {};
  bool _closed = false;
  IndexedDbCollectionBackend(this.databaseName);

  CollectionStorageException _failure(String? name, String? message) {
    final reason = switch (name) {
      'QuotaExceededError' => StorageFailure.quota,
      'SecurityError' ||
      'NotAllowedError' ||
      'InvalidStateError' => StorageFailure.unavailable,
      'VersionError' => StorageFailure.blocked,
      _ => StorageFailure.unknown,
    };
    return CollectionStorageException(reason, '$name: $message');
  }

  Future<web.IDBDatabase> _database() async {
    if (_closed) {
      throw const CollectionStorageException(
        StorageFailure.unavailable,
        'Database closed',
      );
    }
    if (_db != null) return _db!;
    if (_opening != null) return _opening!;
    _opening = _open();
    try {
      return await _opening!;
    } finally {
      _opening = null;
    }
  }

  Future<web.IDBDatabase> _open() {
    final result = Completer<web.IDBDatabase>();
    final timer = Timer(const Duration(seconds: 10), () {
      if (!result.isCompleted) {
        result.completeError(
          const CollectionStorageException(
            StorageFailure.blocked,
            'Opening IndexedDB timed out',
          ),
        );
      }
    });
    try {
      final request = web.window.indexedDB.open(databaseName, 1);
      request.onupgradeneeded = ((web.Event event) {
        final db = request.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_recordsStore)) {
          db.createObjectStore(_recordsStore);
        }
        if (!db.objectStoreNames.contains(_metadataStore)) {
          db.createObjectStore(_metadataStore);
        }
      }).toJS;
      request.onblocked = ((web.Event event) {
        if (!result.isCompleted) {
          result.completeError(
            const CollectionStorageException(
              StorageFailure.blocked,
              'Close other tabs using this database',
            ),
          );
        }
        timer.cancel();
      }).toJS;
      request.onerror = ((web.Event event) {
        if (!result.isCompleted) {
          result.completeError(
            _failure(request.error?.name, request.error?.message),
          );
        }
        timer.cancel();
      }).toJS;
      request.onsuccess = ((web.Event event) {
        timer.cancel();
        final db = request.result as web.IDBDatabase;
        if (result.isCompleted || _closed) {
          db.close();
          if (!result.isCompleted) {
            result.completeError(
              const CollectionStorageException(
                StorageFailure.unavailable,
                'Database closed',
              ),
            );
          }
          return;
        }
        db.onversionchange = ((web.Event event) {
          db.close();
          _db = null;
        }).toJS;
        _db = db;
        result.complete(db);
      }).toJS;
    } catch (error) {
      timer.cancel();
      result.completeError(
        CollectionStorageException(
          StorageFailure.unavailable,
          error.toString(),
        ),
      );
    }
    return result.future;
  }

  Future<void> _completion(
    web.IDBTransaction transaction, {
    CollectionStorageException? Function()? customError,
  }) {
    final result = Completer<void>();
    CollectionStorageException? failure;
    transaction.onerror = ((web.Event event) {
      final request = event.target as web.IDBRequest;
      failure = _failure(request.error?.name, request.error?.message);
      // Do not preventDefault: IndexedDB must abort the entire failed write.
    }).toJS;
    transaction.onabort = ((web.Event event) {
      if (!result.isCompleted) {
        result.completeError(
          customError?.call() ??
              failure ??
              _failure(transaction.error?.name, transaction.error?.message),
        );
      }
    }).toJS;
    transaction.oncomplete = ((web.Event event) {
      if (!result.isCompleted) result.complete();
    }).toJS;
    return result.future.timeout(
      const Duration(seconds: 45),
      onTimeout: () {
        try {
          transaction.abort();
        } catch (_) {}
        throw const CollectionStorageException(
          StorageFailure.unavailable,
          'IndexedDB transaction timed out',
        );
      },
    );
  }

  @override
  Future<CollectionSnapshot?> read() async {
    final db = await _database();
    final transaction = db.transaction(
      [_recordsStore.toJS, _metadataStore.toJS].toJS,
      'readonly',
    );
    final complete = _completion(transaction);
    final store = transaction.objectStore(_recordsStore);
    final keys = store.getAllKeys();
    final rows = store.getAll();
    final metadata = transaction
        .objectStore(_metadataStore)
        .get('collection'.toJS);
    await complete;
    final manifestValue = metadata.result.dartify();
    final storedKeys = keys.result.dartify() as List;
    final storedRows = rows.result.dartify() as List;
    if (manifestValue == null) {
      if (storedKeys.isNotEmpty) {
        throw const CollectionStorageException(
          StorageFailure.corrupt,
          'Records exist without a manifest',
        );
      }
      _cached = {};
      return null;
    }
    final records = <String, String>{};
    for (var i = 0; i < storedKeys.length; i++) {
      records[storedKeys[i] as String] = storedRows[i] as String;
    }
    final snapshot = CollectionSnapshot.fromManifest(
      jsonDecode(manifestValue as String),
      records,
    );
    _cached = Map.of(snapshot.records);
    return snapshot;
  }

  @override
  Future<void> write(
    CollectionSnapshot snapshot, {
    required int? expectedRevision,
  }) async {
    final db = await _database();
    final transaction = db.transaction(
      [_recordsStore.toJS, _metadataStore.toJS].toJS,
      'readwrite',
      web.IDBTransactionOptions(durability: 'strict'),
    );
    CollectionStorageException? failure;
    final complete = _completion(transaction, customError: () => failure);
    final metadata = transaction.objectStore(_metadataStore);
    final readManifest = metadata.get('collection'.toJS);
    readManifest.onsuccess = ((web.Event event) {
      try {
        final value = readManifest.result.dartify();
        final oldManifest = value == null
            ? null
            : jsonDecode(value as String) as Map;
        if (oldManifest != null && oldManifest['schema'] != 1) {
          throw const CollectionStorageException(
            StorageFailure.corrupt,
            'Unsupported collection schema',
          );
        }
        if (oldManifest?['revision'] != expectedRevision) {
          throw const CollectionStorageException(
            StorageFailure.conflict,
            'Collection changed in another tab',
          );
        }
        if (snapshot.revision != (expectedRevision ?? 0) + 1) {
          throw const CollectionStorageException(
            StorageFailure.corrupt,
            'Invalid revision',
          );
        }
        final store = transaction.objectStore(_recordsStore);
        final previousKeys = oldManifest?['keys'] as List? ?? [];
        for (final key in previousKeys) {
          if (!snapshot.records.containsKey(key)) {
            store.delete((key as String).toJS);
          }
        }
        // All requests are queued synchronously inside the success callback.
        // Awaiting between these operations would close the transaction in Safari.
        for (final entry in snapshot.records.entries) {
          if (_cached[entry.key] != entry.value) {
            store.put(entry.value.toJS, entry.key.toJS);
          }
        }
        metadata.put(jsonEncode(snapshot.manifest).toJS, 'collection'.toJS);
      } catch (error) {
        failure = error is CollectionStorageException
            ? error
            : CollectionStorageException(
                StorageFailure.unknown,
                error.toString(),
              );
        transaction.abort();
      }
    }).toJS;
    await complete;
    // Request success is insufficient: acknowledge only the transaction commit.
    _cached = Map.of(snapshot.records);
  }

  @override
  Future<StorageStatus> status() async {
    int? usage;
    int? quota;
    bool? persistent;
    try {
      final estimate = await web.window.navigator.storage
          .estimate()
          .toDart
          .timeout(const Duration(seconds: 3));
      usage = estimate.usage;
      quota = estimate.quota;
    } catch (_) {}
    try {
      persistent =
          (await web.window.navigator.storage.persisted().toDart.timeout(
            const Duration(seconds: 3),
          )).toDart;
    } catch (_) {}
    return StorageStatus(
      name: 'IndexedDB',
      usageBytes: usage,
      quotaBytes: quota,
      persistent: persistent,
    );
  }

  @override
  Future<bool> requestPersistence() async {
    try {
      return (await web.window.navigator.storage.persist().toDart.timeout(
        const Duration(seconds: 5),
      )).toDart;
    } catch (_) {
      return false;
    }
  }

  @override
  void close() {
    _closed = true;
    _db?.close();
    _db = null;
  }
}
