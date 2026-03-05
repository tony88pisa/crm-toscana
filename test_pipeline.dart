import 'dart:io';
import 'lib/services/maps_service.dart';

void main() async {
  print('Test Search: Firenze, Ristorazione');
  try {
    final results = await MapsService.searchBusinesses('Firenze', 'Ristorazione', (p) => print('[Progress] ${p.stepName}: ${p.detail}'));
    print('\n--- PIPELINE ENDED ---');
    print('Found ${results.length} verified prospects.');
    for(var p in results.take(10)) {
      print('- ${p.name}: ${p.sourceType} | AI URGENZA: ${p.aiUrgency} | AI MATCH: ${p.aiMatch}');
    }
  } catch(e) {
    print('ERROR: $e');
  }
}
