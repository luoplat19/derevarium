import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class PlantNetResult {
  final String name;
  final String scientificName;
  final double score;

  PlantNetResult({
    required this.name,
    required this.scientificName,
    required this.score,
  });
}

class PlantNetApi {
  // ==========================================================
  // IDENTIFY PLANT
  // ==========================================================

  static Future<List<PlantNetResult>> identify(
    Uint8List imageBytes,
  ) async {
    // Запит іде через наш Netlify-проксі.
    // API-ключ Pl@ntNet більше не знаходиться у Flutter-коді.
    final uri = Uri.parse('/api/plantnet');

    final request = http.MultipartRequest(
      'POST',
      uri,
    );

    request.files.add(
      http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'tree.jpg',
      ),
    );

    try {
      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final body = await response.stream.bytesToString();

      if (response.statusCode != 200) {
        throw Exception(
          'PlantNet повернув помилку ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'PlantNet повернув некоректну відповідь.',
        );
      }

      final results = decoded['results'];

      if (results is! List || results.isEmpty) {
        return [];
      }

      final List<PlantNetResult> output = [];

      for (final item in results) {
        if (item is! Map) {
          continue;
        }

        final species = item['species'];

        if (species is! Map) {
          continue;
        }

        final scientificName =
            species['scientificNameWithoutAuthor']?.toString() ??
            species['scientificName']?.toString() ??
            'Невідомий вид';

        String commonName = '';

        final commonNames = species['commonNames'];

        if (commonNames is List && commonNames.isNotEmpty) {
          commonName = commonNames.first.toString();
        }

        if (commonName.trim().isEmpty) {
          commonName = scientificName;
        }

        final score =
            (item['score'] as num?)?.toDouble() ?? 0.0;

        output.add(
          PlantNetResult(
            name: commonName,
            scientificName: scientificName,
            score: score,
          ),
        );
      }

      return output;
    } on http.ClientException catch (e) {
      throw Exception(
        'Помилка зʼєднання з PlantNet: $e',
      );
    } on FormatException {
      throw Exception(
        'PlantNet повернув неправильні дані.',
      );
    }
  }
}