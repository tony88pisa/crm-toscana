// lib/services/ai_service.dart
//
// Servizio AI gratuito tramite Google Gemini 2.5 Flash-Lite
// 1000 richieste/giorno GRATIS — valida i risultati di ricerca
// Determina se una notizia è una VERA nuova apertura

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Risultato dell'analisi AI di un lead
class AiAnalysis {
  final bool isRealOpening;     // È una vera nuova apertura?
  final String businessName;    // Nome attività estratto
  final String businessType;    // Tipo (ristorante, bar, negozio...)
  final String location;        // Indirizzo/zona estratta
  final String urgencyLevel;    // 'hot', 'warm', 'cold'
  final String openingTimeframe;// "tra 1 mese", "già aperto", ecc.
  final int confidenceScore;    // 0-100
  final String reasoning;       // Spiegazione breve dell'AI
  final String? vatNumber;      // P.IVA trovata dall'AI
  final String? ownerName;      // Nome titolare o referente
  final String? email;          // Email trovata
  final String? extractedPhone; // Telefono o cellulare trovato

  const AiAnalysis({
    required this.isRealOpening,
    required this.businessName,
    required this.businessType,
    required this.location,
    required this.urgencyLevel,
    required this.openingTimeframe,
    required this.confidenceScore,
    required this.reasoning,
    this.vatNumber,
    this.ownerName,
    this.email,
    this.extractedPhone,
  });

  factory AiAnalysis.notAvailable() => const AiAnalysis(
    isRealOpening: true,
    businessName: '',
    businessType: '',
    location: '',
    urgencyLevel: 'unknown',
    openingTimeframe: '',
    confidenceScore: 30,
    reasoning: 'Analisi AI non disponibile',
    vatNumber: null,
    ownerName: null,
    email: null,
    extractedPhone: null,
  );
}

class AiService {
  // Gemini API - 1000 req/giorno GRATIS con Flash-Lite
  static const _apiKey = 'AIzaSyDoUAZcmCUFUrI3lCbHONcwH9YZxkVVBsY';
  static const _model = 'gemini-2.0-flash-lite';
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// Analizza un risultato di ricerca con AI per determinare
  /// se è una VERA nuova apertura di attività commerciale
  static Future<AiAnalysis> analyzeResult({
    required String title,
    required String description,
    required String province,
  }) async {
    try {
      final prompt = '''Sei un analista commerciale spietato e preciso. Il tuo compito è filtrare i falsi positivi. Analizza questa notizia e determina se riguarda una VERA, NUOVA e IMMINENTE (o appena avvenuta) APERTURA di un'attività commerciale (negozio, ristorante, ecc) nella provincia di $province, Toscana.

NOTIZIA:
Titolo: $title
Descrizione: $description

Rispondi SOLO in formato JSON valido (niente markdown, niente ```), con questi campi:
{
  "is_real_opening": true/false,
  "business_name": "nome esatto dell'attività",
  "business_type": "tipo (ristorante/bar/negozio/farmacia/ecc.)",
  "location": "indirizzo esatto o città menzionata",
  "urgency": "hot/warm/cold",
  "timeframe": "quando apre (es: tra 1 mese, già aperto, data specifica)",
  "confidence": 0-100,
  "reasoning": "spiegazione di MASSIMO 10 parole del perché è o non è una nuova apertura",
  "vat_number": "partita iva o ragione sociale completa (se presente, altrimenti stringa vuota)",
  "owner_name": "nome del titolare o referente o chi assume (se presente, altrimenti stringa vuota)",
  "email": "indirizzo email per CV o contatti (se presente, altrimenti stringa vuota)",
  "extracted_phone": "numero di telefono o cellulare (se presente, altrimenti stringa vuota)"
}

REGOLE TASSATIVE per is_real_opening = FALSE (FALSO POSITIVO - SII PARANOICO):
1. Se è una RECENSIONE di un locale già aperto da molto tempo -> FALSE
2. Se è un EVENTO temporaneo, una sagra, fiera, mercato -> FALSE
3. Se annuncia una CHIUSURA, un fallimento, o una vendita d'azienda -> FALSE
4. Se è un annuncio di LAVORO generico per un posto GIA' APERTO -> FALSE
5. Se è cronaca nera, polemica, furto o incidente -> FALSE
6. Se cita "anniversario", "storico locale", "riapre dopo i lavori", "riapertura estiva", "restyling" -> FALSE (Hanno già i fornitori e le casse)
7. Se NON parla di una VERA, NUOVA e IMMINENTE apertura fisica B2C -> FALSE

Devi mettere TRUE SOLO SE c'è prova concreta che un LOCALE FISICO TOTALMENTE NUOVO sta aprendo, ha appena aperto, o aprirà a breve.

REGOLE per urgency:
- "hot" = apre tra 2+ settimane o cerca personale in vista di un'apertura (vero target)
- "warm" = apre tra 1-2 settimane
- "cold" = già aperto, inaugurato nei giorni scorsi

REGOLE per confidence:
- 90-100 se c'è nome, via esatta e data di un'attività ineffettivamente nuova.
- <50 se è dubbio o potrebbe essere un restyling.''';

      final url = '$_baseUrl/$_model:generateContent?key=$_apiKey';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {
            'temperature': 0.2,
            'maxOutputTokens': 300,
          },
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return AiAnalysis.notAvailable();
      }

      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      
      // Estrai il JSON dalla risposta
      return _parseAiResponse(text);
    } catch (e) {
      return AiAnalysis.notAvailable();
    }
  }

  /// Analizza un batch di risultati (max 5 alla volta per efficienza)
  static Future<List<AiAnalysis>> analyzeBatch({
    required List<Map<String, String>> items,
    required String province,
  }) async {
    if (items.isEmpty) return [];
    
    try {
      final itemsText = items.asMap().entries.map((e) =>
        '${e.key + 1}. Titolo: ${e.value['title']}\n   Descrizione: ${e.value['description']}'
      ).join('\n\n');

      final prompt = '''Sei un analista commerciale spietato. Analizza queste ${items.length} notizie e per OGNUNA determina se riguarda una VERA e NUOVA APERTURA di attività commerciale (negozio/ristorante/ecc) nella provincia di $province, Toscana. SCARTA TUTTI i falsi positivi (recensioni di vecchi locali, eventi, sagre, cronaca, chiusure).

NOTIZIE:
$itemsText

Rispondi SOLO con un array JSON valido (niente markdown, niente \`\`\`). Per ogni notizia:
[
  {
    "index": 1,
    "is_real_opening": true/false,
    "business_name": "nome",
    "business_type": "tipo",
    "location": "indirizzo/zona",
    "urgency": "hot/warm/cold",
    "timeframe": "quando apre/ha aperto",
    "confidence": 0-100,
    "reasoning": "perché è/non è un'apertura (max 10 parole)",
    "vat_number": "partita iva o ragione sociale (se trovata)",
    "owner_name": "nome titolare/referente (se trovato)",
    "email": "email (se trovata)",
    "extracted_phone": "telefono (se trovato)"
  }
]

REGOLE RIGIDE PARANOICHE per is_real_opening = FALSE:
- is_real_opening = FALSE se: recensione vecchio locale, evento/sagra, chiusura, furto, annuncio lavoro per posto esistente, "storico", "restyling", "rinnovo locali", "riapertura estiva", "anniversario".
- is_real_opening = TRUE SOLO SE: nuovo locale fisico, startup da zero, subentro totale.
- URGENCY: hot=cerca personale per futura apertura o apre tra 2+ sett, warm=1-2 sett, cold=già aperto.''';

      final url = '$_baseUrl/$_model:generateContent?key=$_apiKey';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [{'parts': [{'text': prompt}]}],
          'generationConfig': {
            'temperature': 0.2,
            'maxOutputTokens': 800,
          },
        }),
      ).timeout(const Duration(seconds: 25));

      if (response.statusCode != 200) {
        return List.generate(items.length, (_) => AiAnalysis.notAvailable());
      }

      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
      
      return _parseBatchResponse(text, items.length);
    } catch (e) {
      return List.generate(items.length, (_) => AiAnalysis.notAvailable());
    }
  }

  static AiAnalysis _parseAiResponse(String text) {
    try {
      // Trova il JSON nella risposta
      final jsonStr = _extractJson(text);
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      return AiAnalysis(
        isRealOpening: json['is_real_opening'] == true,
        businessName: json['business_name']?.toString() ?? '',
        businessType: json['business_type']?.toString() ?? '',
        location: json['location']?.toString() ?? '',
        urgencyLevel: json['urgency']?.toString() ?? 'unknown',
        openingTimeframe: json['timeframe']?.toString() ?? '',
        confidenceScore: (json['confidence'] as num?)?.toInt() ?? 30,
        reasoning: json['reasoning']?.toString() ?? '',
        vatNumber: json['vat_number']?.toString(),
        ownerName: json['owner_name']?.toString(),
        email: json['email']?.toString(),
        extractedPhone: json['extracted_phone']?.toString(),
      );
    } catch (_) {
      return AiAnalysis.notAvailable();
    }
  }

  static List<AiAnalysis> _parseBatchResponse(String text, int expectedCount) {
    try {
      final jsonStr = _extractJson(text);
      final list = jsonDecode(jsonStr) as List<dynamic>;
      
      return list.map((json) {
        final m = json as Map<String, dynamic>;
        return AiAnalysis(
          isRealOpening: m['is_real_opening'] == true,
          businessName: m['business_name']?.toString() ?? '',
          businessType: m['business_type']?.toString() ?? '',
          location: m['location']?.toString() ?? '',
          urgencyLevel: m['urgency']?.toString() ?? 'unknown',
          openingTimeframe: m['timeframe']?.toString() ?? '',
          confidenceScore: (m['confidence'] as num?)?.toInt() ?? 30,
          reasoning: m['reasoning']?.toString() ?? '',
          vatNumber: m['vat_number']?.toString(),
          ownerName: m['owner_name']?.toString(),
          email: m['email']?.toString(),
          extractedPhone: m['extracted_phone']?.toString(),
        );
      }).toList();
    } catch (_) {
      return List.generate(expectedCount, (_) => AiAnalysis.notAvailable());
    }
  }

  /// Estrai JSON da una risposta che potrebbe contenere altro testo
  static String _extractJson(String text) {
    // Rimuovi markdown code blocks
    text = text.replaceAll('```json', '').replaceAll('```', '').trim();
    
    // Trova array JSON
    final arrayStart = text.indexOf('[');
    final arrayEnd = text.lastIndexOf(']');
    if (arrayStart != -1 && arrayEnd > arrayStart) {
      return text.substring(arrayStart, arrayEnd + 1);
    }
    
    // Trova object JSON
    final objStart = text.indexOf('{');
    final objEnd = text.lastIndexOf('}');
    if (objStart != -1 && objEnd > objStart) {
      return text.substring(objStart, objEnd + 1);
    }
    
    return text;
  }
}
