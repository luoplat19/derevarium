import 'dart:convert';
import 'dart:math';

String newTreeId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class Tree {
  final String id;
  final String type;
  final String location;
  final String locationType;
  final String facts;
  final String notes;
  final String? imageBase64;
  final DateTime dateFound;
  final bool foundTogether;
  final bool isRare;

  Tree({
    String? id,
    required this.type,
    required this.location,
    required this.locationType,
    required this.facts,
    this.notes = '',
    required this.dateFound,
    this.imageBase64,
    this.foundTogether = false,
    this.isRare = false,
  }) : id = id ?? newTreeId();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'location': location,
    'locationType': locationType,
    'facts': facts,
    'notes': notes,
    'imageBase64': imageBase64,
    'dateFound': dateFound.toIso8601String(),
    'foundTogether': foundTogether,
    'isRare': isRare,
  };

  factory Tree.fromJson(Map<String, dynamic> json) {
    for (final field in [
      'id',
      'type',
      'name',
      'location',
      'locationType',
      'facts',
      'notes',
      'imageBase64',
      'dateFound',
    ]) {
      if (json[field] != null && json[field] is! String) {
        throw FormatException('Некоректне поле $field');
      }
    }
    for (final field in ['foundTogether', 'isRare']) {
      if (json[field] != null && json[field] is! bool) {
        throw FormatException('Некоректне поле $field');
      }
    }
    final id = json['id'] as String?;
    if (id != null && (id.isEmpty || id.length > 200)) {
      throw const FormatException('Некоректний ідентифікатор дерева');
    }
    if (json['imageBase64'] != null) {
      base64Decode(json['imageBase64'] as String);
    }
    return Tree(
      id: id,
      type: json['type'] ?? json['name'] ?? '',
      location: json['location'] ?? '',
      locationType: json['locationType'] ?? 'Місто',
      facts: json['facts'] ?? '',
      notes: json['notes'] ?? '',
      imageBase64: json['imageBase64'],
      dateFound: DateTime.tryParse(json['dateFound'] ?? '') ?? DateTime.now(),
      foundTogether: json['foundTogether'] ?? false,
      isRare: json['isRare'] ?? false,
    );
  }
}
