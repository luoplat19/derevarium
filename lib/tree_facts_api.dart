import 'dart:convert';

import 'package:http/http.dart' as http;

class TreeFactsResult {
  final String facts;
  final String sourceUrl;

  TreeFactsResult({
    required this.facts,
    required this.sourceUrl,
  });
}

class TreeFactsApi {
  static const String _baseUrl =
      'https://uk.wikipedia.org/api/rest_v1';

  static Future<TreeFactsResult?> getFacts({
    required String commonName,
    required String scientificName,
  }) async {
    // Спочатку пробуємо звичайну назву.
    TreeFactsResult? result =
        await _getSummary(commonName);

    // Якщо сторінки за звичайною назвою немає —
    // пробуємо наукову.
    if (result == null &&
        scientificName.trim().isNotEmpty) {
      result = await _getSummary(scientificName);
    }

    // Якщо все одно нічого не знайшли —
    // пробуємо пошук Wikipedia.
    if (result == null) {
      result = await _searchAndGetSummary(commonName);
    }

    if (result == null &&
        scientificName.trim().isNotEmpty) {
      result =
          await _searchAndGetSummary(scientificName);
    }

    return result;
  }

  static Future<TreeFactsResult?> _getSummary(
    String title,
  ) async {
    final cleanTitle = title.trim();

    if (cleanTitle.isEmpty) {
      return null;
    }

    try {
      final encodedTitle =
          Uri.encodeComponent(cleanTitle);

      final uri = Uri.parse(
        '$_baseUrl/page/summary/$encodedTitle',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      final extract =
          data['extract']?.toString().trim() ?? '';

      final pageUrl =
          data['content_urls']?['desktop']?['page']
                  ?.toString() ??
              '';

      if (extract.isEmpty) {
        return null;
      }

      final facts = _makeFacts(extract);

      if (facts.isEmpty) {
        return null;
      }

      return TreeFactsResult(
        facts: facts,
        sourceUrl: pageUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<TreeFactsResult?>
      _searchAndGetSummary(
    String query,
  ) async {
    final cleanQuery = query.trim();

    if (cleanQuery.isEmpty) {
      return null;
    }

    try {
      final uri = Uri.parse(
        'https://uk.wikipedia.org/w/rest.php/v1/search/page'
        '?q=${Uri.encodeQueryComponent(cleanQuery)}'
        '&limit=3',
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      final pages = data['pages'];

      if (pages is! List || pages.isEmpty) {
        return null;
      }

      for (final page in pages) {
        if (page is! Map) {
          continue;
        }

        final title =
            page['title']?.toString().trim() ?? '';

        if (title.isEmpty) {
          continue;
        }

        final result =
            await _getSummary(title);

        if (result != null) {
          return result;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  static String _makeFacts(String extract) {
    final cleanText = extract
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    if (cleanText.isEmpty) {
      return '';
    }

    // Приблизно ділимо текст на речення.
    final sentences = cleanText
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((e) => e.trim())
        .where((e) => e.length > 20)
        .toList();

    if (sentences.isEmpty) {
      return cleanText;
    }

    // Беремо максимум 4 речення.
    final selected = sentences.take(4).toList();

    return selected
        .map((sentence) => '🌿 $sentence')
        .join('\n\n');
  }
}