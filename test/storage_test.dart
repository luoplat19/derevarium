import 'dart:convert';
import 'dart:typed_data';

import 'package:derevarium/backup.dart';
import 'package:derevarium/photo.dart';
import 'package:derevarium/storage_backend.dart';
import 'package:derevarium/tree.dart';
import 'package:derevarium/tree_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

Tree sample({String? id, String notes = '', String? photo}) => Tree(
  id: id,
  type: 'Дуб',
  location: 'Чернівці',
  locationType: 'Парк',
  facts: 'Довговічне дерево',
  notes: notes,
  imageBase64: photo,
  dateFound: DateTime(2026, 10, 11),
  foundTogether: true,
  isRare: true,
);

class MemoryBackend implements CollectionBackend {
  CollectionSnapshot? snapshot;
  bool reject = false;
  @override
  Future<CollectionSnapshot?> read() async => snapshot;
  @override
  Future<void> write(
    CollectionSnapshot next, {
    required int? expectedRevision,
  }) async {
    if (reject) {
      throw const CollectionStorageException(
        StorageFailure.quota,
        'Test quota',
      );
    }
    if (snapshot?.revision != expectedRevision) {
      throw const CollectionStorageException(
        StorageFailure.conflict,
        'Changed',
      );
    }
    snapshot = next;
  }

  @override
  Future<StorageStatus> status() async => const StorageStatus(name: 'Test');
  @override
  Future<bool> requestPersistence() async => false;
  @override
  void close() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Migration preserves photos, legacy rows, unreadable rows and stable IDs',
    () async {
      final oldTree = sample(photo: base64Encode([1, 2, 3])).toJson()
        ..remove('id');
      final rows = [
        jsonEncode(oldTree),
        '{broken',
        jsonEncode({'type': 42}),
      ];
      SharedPreferences.setMockInitialValues({'trees': rows});
      final backend = MemoryBackend();
      final repo = TreeRepository(backend: backend);
      final migrated = await repo.load();
      expect(migrated.trees.single.imageBase64, oldTree['imageBase64']);
      expect(migrated.unreadable.values, containsAll(rows.skip(1)));
      expect(
        (await SharedPreferences.getInstance()).getStringList('trees'),
        rows,
      );
      final reopened = await TreeRepository(backend: backend).load();
      expect(reopened.trees.single.toJson(), migrated.trees.single.toJson());
      await repo.save([...migrated.trees, sample()], migrated.unreadable);
      expect(backend.snapshot!.records.values, containsAll(rows.skip(1)));
    },
  );

  test(
    'Failed migration leaves legacy collection available for retry',
    () async {
      final rows = [jsonEncode(sample().toJson())];
      SharedPreferences.setMockInitialValues({'trees': rows});
      final backend = MemoryBackend()..reject = true;
      final repo = TreeRepository(backend: backend);
      await expectLater(
        repo.load(),
        throwsA(isA<CollectionStorageException>()),
      );
      expect(backend.snapshot, isNull);
      expect(
        (await SharedPreferences.getInstance()).getStringList('trees'),
        rows,
      );
      backend.reject = false;
      expect((await repo.load()).trees, hasLength(1));
    },
  );

  test('An empty saved collection does not resurrect legacy trees', () async {
    SharedPreferences.setMockInitialValues({
      'trees': [jsonEncode(sample().toJson())],
    });
    final backend = MemoryBackend();
    final repo = TreeRepository(backend: backend);
    await repo.load();
    await repo.save([], {});
    expect((await TreeRepository(backend: backend).load()).trees, isEmpty);
  });

  test(
    'Failed save preserves the committed revision and supports retry',
    () async {
      final backend = MemoryBackend();
      final repo = TreeRepository(backend: backend);
      await repo.load();
      await repo.save([sample(id: 'oak', notes: 'Оригінал')], {});
      final before = backend.snapshot;
      backend.reject = true;
      await expectLater(
        repo.save([sample(id: 'oak', notes: 'Зміна')], {}),
        throwsA(isA<CollectionStorageException>()),
      );
      expect(backend.snapshot, same(before));
      backend.reject = false;
      await repo.save([sample(id: 'oak', notes: 'Зміна')], {});
      expect((await repo.load()).trees.single.notes, 'Зміна');
      expect(backend.snapshot!.revision, before!.revision + 1);
    },
  );

  test('A stale collection cannot overwrite another tab', () async {
    final backend = MemoryBackend();
    final first = TreeRepository(backend: backend);
    final second = TreeRepository(backend: backend);
    await first.load();
    await second.load();
    await first.save([sample(id: 'first')], {});
    await expectLater(
      second.save([sample(id: 'second')], {}),
      throwsA(
        isA<CollectionStorageException>().having(
          (e) => e.reason,
          'reason',
          StorageFailure.conflict,
        ),
      ),
    );
    expect((await second.load()).trees.single.id, 'first');
  });

  test('Backup round-trip preserves all fields, photos and unreadable rows for 500 trees', () {
    final trees = List.generate(
      500,
      (i) => sample(
        id: 'tree-$i',
        notes: 'Наша історія $i',
        photo: base64Encode([i % 256, 2, 3]),
      ),
    );
    final backup = BackupData(
      createdAt: DateTime.utc(2026),
      trees: trees,
      unreadable: {'raw': '{broken'},
    );
    final restored = BackupData.decode(backup.encode());
    expect(restored.createdAt, backup.createdAt);
    expect(
      restored.trees.map((t) => t.toJson()).toList(),
      trees.map((t) => t.toJson()).toList(),
    );
    expect(restored.unreadable, backup.unreadable);
  });

  test(
    'Backup rejects unsupported versions, duplicated IDs and invalid photos',
    () {
      final backup = BackupData(
        createdAt: DateTime.now(),
        trees: [sample(id: 'oak')],
        unreadable: {},
      );
      for (final change in [
        (Map<String, dynamic> json) => json['version'] = 99,
        (Map<String, dynamic> json) =>
            (json['trees'] as List).add((json['trees'] as List).first),
        (Map<String, dynamic> json) =>
            (json['trees'] as List).first['imageBase64'] = 'not a photo',
        (Map<String, dynamic> json) =>
            json['unreadable'] = {'oak': 'collision'},
      ]) {
        final json =
            jsonDecode(utf8.decode(backup.encode())) as Map<String, dynamic>;
        change(json);
        expect(
          () => BackupData.decode(
            Uint8List.fromList(utf8.encode(jsonEncode(json))),
          ),
          throwsFormatException,
        );
      }
      expect(
        () => BackupData.decode(Uint8List.fromList(utf8.encode('{broken'))),
        throwsFormatException,
      );
    },
  );

  test(
    'Restore updates matching IDs without duplicating or removing other trees',
    () {
      final current = TreeCollection(
        [sample(id: 'oak', notes: 'Нове'), sample(id: 'pine')],
        {'current-raw': 'raw'},
      );
      final backup = BackupData(
        createdAt: DateTime.now(),
        trees: [
          sample(id: 'oak', notes: 'З копії'),
          sample(id: 'birch'),
        ],
        unreadable: {'backup-raw': 'raw'},
      );
      final restored = backup.mergeInto(current);
      expect(restored.trees.map((t) => t.id), ['oak', 'pine', 'birch']);
      expect(restored.trees.first.notes, 'З копії');
      expect(
        restored.unreadable.keys,
        containsAll(['current-raw', 'backup-raw']),
      );
      expect(backup.mergeInto(restored).trees, hasLength(3));
    },
  );

  test(
    'Photo compression bounds both portrait and landscape without upscaling',
    () {
      for (final dimensions in [
        (width: 800, height: 1600),
        (width: 1600, height: 800),
        (width: 200, height: 300),
      ]) {
        final photo = img.Image(
          width: dimensions.width,
          height: dimensions.height,
        );
        final compressed = compressTreePhoto(img.encodePng(photo));
        final decoded = img.decodeJpg(compressed)!;
        expect(decoded.width, lessThanOrEqualTo(1000));
        expect(decoded.height, lessThanOrEqualTo(1000));
        expect(
          decoded.width / decoded.height,
          closeTo(photo.width / photo.height, 0.01),
        );
        expect(decoded.width, lessThanOrEqualTo(photo.width));
        expect(decoded.height, lessThanOrEqualTo(photo.height));
      }
      final unknown = Uint8List.fromList([1, 2, 3]);
      expect(compressTreePhoto(unknown), same(unknown));
    },
  );
}
