import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

void main() async {
  final url = 'https://www.infojobs.it/offerte-lavoro/nuova-apertura/provincia-firenze';
  final r = await http.get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0'});
  final doc = parse(r.body);
  
  // Find listing titles in infojobs (usually h2 with class 'ij-OfferCardContent-description-title')
  final titles = doc.querySelectorAll('h2');
  print('Found \ h2 elements. First 3:');
  for (var i = 0; i < titles.length && i < 3; i++) {
    print('- \');
  }

  // Find links
  final locs = doc.querySelectorAll('.ij-OfferCardContent-description-list-item');
  print('Found \ loc elements.');
}
