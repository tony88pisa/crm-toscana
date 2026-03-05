import 'dart:io';
import 'lib/services/hr_scraper_service.dart';
import 'lib/services/ai_service.dart';

void main() async {
  print('Testing Scraper: Firenze');
  final hr = await HrScraperService.scrapeAllHrSources('Firenze');
  print('Found ${hr.length} HR leads.');
  for(final h in hr) {
    print('- ${h['title']} (${h['sourceName']})');
    print('  URL: ${h['url']}');
  }
}
