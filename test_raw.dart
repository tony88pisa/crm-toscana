import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  
  // Test Subito
  final urlSubito = 'https://www.subito.it/annunci-toscana/vendita/offerte-lavoro/firenze/?q=nuova+apertura';
  final rSub = await http.get(Uri.parse(urlSubito), headers: {'User-Agent': userAgent});
  print('--- SUBITO HTTP: ${rSub.statusCode} LENGTH: ${rSub.body.length}');
  
  // Scrivi su file locale per poterlo leggere con grep
  File('raw_subito.html').writeAsStringSync(rSub.body);

  // Test Infojobs
  final urlIj = 'https://www.infojobs.it/offerte-lavoro/nuova-apertura/provincia-firenze';
  final rIj = await http.get(Uri.parse(urlIj), headers: {'User-Agent': userAgent});
  print('--- INFOJOBS HTTP: ${rIj.statusCode} LENGTH: ${rIj.body.length}');
  
  // Scrivi su file locale per poterlo leggere con grep
  File('raw_infojobs.html').writeAsStringSync(rIj.body);
  
  print('Done.');
}
