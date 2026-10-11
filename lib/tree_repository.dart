import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'storage_backend.dart';
import 'storage_backend_factory.dart';
import 'tree.dart';

class TreeCollection {
  final List<Tree> trees;
  final Map<String, String> unreadable;
  TreeCollection(List<Tree> trees, Map<String, String> unreadable)
    : trees = List.unmodifiable(trees),
      unreadable = Map.unmodifiable(unreadable);
}

class TreeRepository {
  final CollectionBackend backend;
  int? _revision;
  final Map<String, ({Tree tree, String encoded})> _encoded = {};
  TreeRepository({CollectionBackend? backend})
    : backend = backend ?? createCollectionBackend();

  Future<TreeCollection> load() async {
    var snapshot = await backend.read();
    if (snapshot == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final legacyRows = prefs.getStringList('trees') ?? [];
      final records = <String, String>{};
      for (final row in legacyRows) {
        try {
          var tree = Tree.fromJson(jsonDecode(row) as Map<String, dynamic>);
          if (records.containsKey(tree.id)) {
            tree = Tree.fromJson({...tree.toJson(), 'id': newTreeId()});
          }
          records[tree.id] = jsonEncode(tree.toJson());
        } catch (_) {
          records['unreadable-${newTreeId()}'] = row;
        }
      }
      snapshot = CollectionSnapshot(revision: 1, records: records);
      try {
        // The legacy key is deliberately retained, including after migration.
        await backend.write(snapshot, expectedRevision: null);
      } on CollectionStorageException catch (error) {
        if (error.reason != StorageFailure.conflict) rethrow;
        snapshot = await backend.read();
        if (snapshot == null) rethrow;
      }
    }
    _revision = snapshot.revision;
    _encoded.clear();
    final trees = <Tree>[];
    final unreadable = <String, String>{};
    for (final entry in snapshot.records.entries) {
      try {
        final tree = Tree.fromJson(
          jsonDecode(entry.value) as Map<String, dynamic>,
        );
        if (tree.id != entry.key) {
          throw const FormatException('Tree ID does not match record key');
        }
        trees.add(tree);
        _encoded[tree.id] = (tree: tree, encoded: entry.value);
      } catch (_) {
        unreadable[entry.key] = entry.value;
      }
    }
    return TreeCollection(trees, unreadable);
  }

  Future<void> save(List<Tree> trees, Map<String, String> unreadable) async {
    if (_revision == null) {
      throw StateError('Load the collection before saving');
    }
    final records = <String, String>{};
    final nextEncoded = <String, ({Tree tree, String encoded})>{};
    for (final tree in trees) {
      if (records.containsKey(tree.id) || unreadable.containsKey(tree.id)) {
        throw const FormatException('Duplicated tree ID');
      }
      final cached = _encoded[tree.id];
      final encoded = cached != null && identical(cached.tree, tree)
          ? cached.encoded
          : jsonEncode(tree.toJson());
      records[tree.id] = encoded;
      nextEncoded[tree.id] = (tree: tree, encoded: encoded);
    }
    records.addAll(unreadable);
    final snapshot = CollectionSnapshot(
      revision: _revision! + 1,
      records: records,
    );
    await backend.write(snapshot, expectedRevision: _revision);
    _revision = snapshot.revision;
    _encoded
      ..clear()
      ..addAll(nextEncoded);
  }

  void close() => backend.close();
}
