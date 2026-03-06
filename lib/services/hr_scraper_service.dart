import 'package:http/http.dart' as http;
import 'dart:convert';

class HrScraperService {
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static Future<List<Map<String, String>>> scrapeSubito(String province) async {
    final List<Map<String, String>> results = [];
    final safeProvince = Uri.encodeComponent(province.toLowerCase());
    final url =
        'https://www.subito.it/annunci-toscana/vendita/offerte-lavoro/$safeProvince/?q=nuova+apertura';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('Scraper Subito: HTTP error ${response.statusCode}');
        return [];
      }

      final body = response.body;

      // Subito uses NextJS. The data is inside <script id="__NEXT_DATA__" type="application/json">
      final regex = RegExp(r'<script id="__NEXT_DATA__" type="application/json">(.*?)</script>');
      final match = regex.firstMatch(body);
      
      if (match != null) {
        try {
          final jsonStr = match.group(1)!;
          final data = jsonDecode(jsonStr);
          
          final list = data['props']?['pageProps']?['initialState']?['items']?['list'] as List?;
          if (list != null) {
            for (var elem in list) {
              final item = elem['item'];
              if (item == null || item['kind'] != 'AdItem') continue;

              final title = item['subject']?.toString() ?? '';
              final description = item['body']?.toString() ?? '';
              final url = item['urls']?['default']?.toString() ?? '';

              if (title.isNotEmpty && url.isNotEmpty) {
                results.add({
                  'title': title,
                  'description': description.length > 300 ? '${description.substring(0, 300)}...' : description,
                  'url': url,
                  'sourceName': 'Subito.it (Lavoro)',
                  'sourceType': 'hr_subito',
                  'province': province,
                });
              }

              if (results.length >= 15) break;
            }
          }
        } catch (e) {
          print('Subito JSON parse error: $e');
        }
      } else {
        print('Scraper Subito: _NEXT_DATA_ not found');
      }

      print('Scraper Subito: Trovati ${results.length} annunci per $province');
    } catch (e) {
      print('Scraper Subito Error: $e');
    }

    return results;
  }

  static Future<List<Map<String, String>>> scrapeInfojobs(String province) async {
    // Infojobs is currently blocking scraping via Cloudflare. Disabled temporarily.
    print('Scraper Infojobs: Temporarily disabled due to anti-bot block');
    return [];
  }

  /// Esegue lo scraping parallelo su tutte le fonti HR supportate
  static Future<List<Map<String, String>>> scrapeAllHrSources(String province) async {
    print('Avvio HR Scraper per $province...');
    final results = await Future.wait([
      scrapeSubito(province),
      scrapeInfojobs(province),
    ]);

    final combined = results.expand((x) => x).toList();
    print('HR Scraper Totale: trovati ${combined.length} annunci unici.');
    return combined;
  }
}
