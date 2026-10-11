import 'dart:convert';
import 'dart:math';

import 'package:derevarium/backup.dart';
import 'package:derevarium/storage_backend.dart';
import 'package:derevarium/storage_backend_factory.dart';
import 'package:derevarium/tree.dart';
import 'package:derevarium/tree_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  var sequence = 0;
  String databaseName() =>
      'derevarium_test_${DateTime.now().microsecondsSinceEpoch}_${sequence++}';
  CollectionBackend open(String name) {
    final backend = createCollectionBackend(databaseName: name);
    addTearDown(backend.close);
    return backend;
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'IndexedDB migration preserves legacy data and record order on reopen',
    () async {
      final name = databaseName();
      final tree = Tree(
        type: 'Дуб',
        location: 'Чернівці',
        locationType: 'Парк',
        facts: 'Факти',
        notes: 'Історія',
        imageBase64: base64Encode(
          img.encodeJpg(img.Image(width: 2, height: 2)),
        ),
        dateFound: DateTime(2026),
      );
      final legacy = [jsonEncode(tree.toJson()..remove('id')), '{broken'];
      SharedPreferences.setMockInitialValues({'trees': legacy});
      final repo = TreeRepository(backend: open(name));
      final migrated = await repo.load();
      final added = Tree.fromJson({...tree.toJson(), 'id': 'added'});
      await repo.save([...migrated.trees, added], migrated.unreadable);
      repo.close();
      final reopened = await TreeRepository(backend: open(name)).load();
      expect(reopened.trees.map((t) => t.id), [
        migrated.trees.single.id,
        added.id,
      ]);
      expect(reopened.trees.first.imageBase64, tree.imageBase64);
      expect(reopened.unreadable.values, ['{broken']);
      expect(
        (await SharedPreferences.getInstance()).getStringList('trees'),
        legacy,
      );
    },
    skip: !kIsWeb,
  );

  test(
    'IndexedDB stores 500 trees with JPEG photos beyond the localStorage limit',
    () async {
      final name = databaseName();
      final random = Random(42);
      final image = img.Image(width: 200, height: 200);
      for (final pixel in image) {
        pixel.setRgb(
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
      }
      final photo = base64Encode(img.encodeJpg(image, quality: 70));
      final trees = List.generate(
        500,
        (i) => Tree(
          id: 'tree-$i',
          type: 'Дуб $i',
          location: 'Парк',
          locationType: 'Місто',
          facts: 'Факти $i',
          notes: 'Наша історія $i',
          imageBase64: photo,
          dateFound: DateTime(2026, 1, 1).add(Duration(days: i)),
          foundTogether: i.isEven,
          isRare: i % 3 == 0,
        ),
      );
      expect(
        trees.fold<int>(
          0,
          (sum, t) => sum + utf8.encode(jsonEncode(t.toJson())).length,
        ),
        greaterThan(5 * 1024 * 1024),
      );
      final repo = TreeRepository(backend: open(name));
      await repo.load();
      await repo.save(trees, {});
      repo.close();
      final next = TreeRepository(backend: open(name));
      final loaded = await next.load();
      expect(
        loaded.trees.map((t) => t.toJson()).toList(),
        trees.map((t) => t.toJson()).toList(),
      );
      final edited = Tree.fromJson({
        ...loaded.trees[250].toJson(),
        'notes': 'Оновлено',
      });
      final updated = List<Tree>.of(loaded.trees)..[250] = edited;
      updated.removeAt(0);
      await next.save(updated, {});
      next.close();
      final restored = await TreeRepository(backend: open(name)).load();
      expect(restored.trees, hasLength(499));
      expect(restored.trees[249].notes, 'Оновлено');
      expect(restored.trees.first.imageBase64, photo);
      final backup = BackupData(
        createdAt: DateTime.now(),
        trees: restored.trees,
        unreadable: restored.unreadable,
      );
      final decoded = BackupData.decode(backup.encode());
      final destination = TreeRepository(backend: open(databaseName()));
      await destination.load();
      await destination.save(decoded.trees, decoded.unreadable);
      expect(
        (await destination.load()).trees.map((t) => t.toJson()).toList(),
        updated.map((t) => t.toJson()).toList(),
      );
    },
    skip: !kIsWeb,
    timeout: const Timeout(Duration(minutes: 2)),
  );

  test('IndexedDB rejects stale and invalid writes without changing committed data', () async {
    final name = databaseName();
    final first = open(name);
    final second = open(name);
    await first.write(
      CollectionSnapshot(revision: 1, records: {'first': 'original'}),
      expectedRevision: null,
    );
    await second.read();
    await first.write(
      CollectionSnapshot(
        revision: 2,
        records: {'first': 'updated', 'new': 'new'},
      ),
      expectedRevision: 1,
    );
    await expectLater(
      second.write(
        CollectionSnapshot(revision: 2, records: {'wrong': 'wrong'}),
        expectedRevision: 1,
      ),
      throwsA(
        isA<CollectionStorageException>().having(
          (e) => e.reason,
          'reason',
          StorageFailure.conflict,
        ),
      ),
    );
    await expectLater(
      first.write(
        CollectionSnapshot(revision: 9, records: {}),
        expectedRevision: 2,
      ),
      throwsA(
        isA<CollectionStorageException>().having(
          (e) => e.reason,
          'reason',
          StorageFailure.corrupt,
        ),
      ),
    );
    expect((await second.read())!.records, {'first': 'updated', 'new': 'new'});
    await second.write(
      CollectionSnapshot(revision: 3, records: {}),
      expectedRevision: 2,
    );
    expect((await first.read())!.records, isEmpty);
    expect((await first.read())!.revision, 3);
    final status = await first.status();
    expect(status.name, 'IndexedDB');
    expect(status.quotaBytes, greaterThan(0));
  }, skip: !kIsWeb);
}
