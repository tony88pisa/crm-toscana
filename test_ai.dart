import 'dart:io';
import 'lib/services/ai_service.dart';

void main() async {
  final items = [
    {
      'title': 'Camerieri, commis di sala, baristi',
      'description': 'Per un\'importante realtà nel mondo della ristorazione... siamo alla ricerca per l\'apertura di una nuova sede a Firenze, di personale di Sala...'
    },
    {
      'title': 'Rider per consegne con scooter',
      'description': 'Società leader nel settore delle consegne... per apertura nuova filiale ricerca due collaboratori con scooter per consegne di piccoli pezzi...'
    }
  ];
  
  print('Testing analyzer on 2 HR leads...');
  final res = await AiService.analyzeBatch(items: items, province: 'Firenze');
  for (var r in res) {
    print('IS_REAL: ${r.isRealOpening} | NAME: ${r.businessName} | TYPE: ${r.businessType}');
    print('URGENCY: ${r.urgencyLevel} | CONF: ${r.confidenceScore} | REASON: ${r.reasoning}');
    print('---');
  }
}
