import 'package:crm_toscana/services/ai_service.dart';

void main() async {
  print('Testing analyzer on user reported Facebook Post (Ava Hair - Jan 19)...');
  final res = await AiService.analyzeResult(
    title: "NUOVA APERTURA A FIRENZE SUD, UN SALONE NON TRADIZIONALE: E 'AVA HAIR & BEAUTY'",
    description: "19 gen \u2022 NOVITA A FIRENZE SUD, UN NUOVO SALONE NON TRADIZIONALE... Benessere e relax a Firenze Sud, il nuovo progetto di Arta...",
    province: 'Firenze'
  );

  print('--- RESULTS ---');
  print('IS_REAL_OPENING: ${res.isRealOpening}');
  print('BUSINESS_NAME: ${res.businessName}');
  print('URGENCY: ${res.urgencyLevel}');
  print('TIMEFRAME: ${res.openingTimeframe}');
  print('REASONING: ${res.reasoning}');
}
