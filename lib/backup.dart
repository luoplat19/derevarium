import 'dart:convert';
import 'dart:typed_data';

import 'tree.dart';
import 'tree_repository.dart';

class BackupData {
  final DateTime createdAt;
  final List<Tree> trees;
  final Map<String, String> unreadable;
  BackupData({
    required this.createdAt,
    required List<Tree> trees,
    required Map<String, String> unreadable,
  }) : trees = List.unmodifiable(trees),
       unreadable = Map.unmodifiable(unreadable);

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'format': 'derevarium-backup',
        'version': 1,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'trees': trees.map((tree) => tree.toJson()).toList(),
        'unreadable': unreadable,
      }),
    ),
  );

  factory BackupData.decode(Uint8List bytes) {
    final value = jsonDecode(
      utf8.decode(bytes).replaceFirst(RegExp(r'^\uFEFF'), ''),
    );
    if (value is! Map<String, dynamic> ||
        value['format'] != 'derevarium-backup' ||
        value['version'] != 1 ||
        value['createdAt'] is! String ||
        value['trees'] is! List ||
        value['unreadable'] is! Map) {
      throw const FormatException('Це не підтримувана копія Derevarium.');
    }
    final createdAt = DateTime.tryParse(value['createdAt'] as String);
    if (createdAt == null) {
      throw const FormatException('Некоректна дата копії.');
    }
    final trees = <Tree>[];
    final ids = <String>{};
    for (final row in value['trees'] as List) {
      if (row is! Map<String, dynamic> ||
          row['id'] is! String ||
          row['dateFound'] is! String ||
          DateTime.tryParse(row['dateFound'] as String) == null) {
        throw const FormatException('У копії є некоректний запис дерева.');
      }
      final tree = Tree.fromJson(row);
      if (!ids.add(tree.id)) {
        throw const FormatException(
          'У копії повторюється ідентифікатор дерева.',
        );
      }
      trees.add(tree);
    }
    final unreadable = Map<String, String>.from(value['unreadable'] as Map);
    if (unreadable.keys.any(ids.contains)) {
      throw const FormatException('У копії повторюється запис.');
    }
    return BackupData(
      createdAt: createdAt,
      trees: trees,
      unreadable: unreadable,
    );
  }

  TreeCollection mergeInto(TreeCollection current) {
    final merged = {for (final tree in current.trees) tree.id: tree};
    for (final tree in trees) {
      merged[tree.id] = tree;
    }
    final invalid = {...current.unreadable, ...unreadable}
      ..removeWhere((key, _) => merged.containsKey(key));
    return TreeCollection(merged.values.toList(), invalid);
  }
}
