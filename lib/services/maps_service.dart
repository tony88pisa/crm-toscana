// lib/services/maps_service.dart
//
// Pipeline di ricerca PRECISA v3 per nuove aperture attività in Toscana.
// Step 1: Scoperta multi-fonte (Google News RSS + DuckDuckGo + Albo Pretorio)
// Step 2: Verifica (Google Places API - 10k/mese gratis)
// Step 3: Scoring urgenza + cross-validazione

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/prospect.dart';
import '../database/database_helper.dart';
import 'ai_service.dart';

// ─── CONFIGURAZIONE ────────────────────────────────────────────────────────
const String kGoogleApiKey = 'AIzaSyDoUAZcmCUFUrI3lCbHONcwH9YZxkVVBsY';
const int kMonthlyApiLimit = 9500;

// ─── PROVINCE TOSCANE ──────────────────────────────────────────────────────
const Map<String, _ProvinceBias> kProvince = {
  'Firenze':         _ProvinceBias(43.7696, 11.2558, 35000),
  'Siena':           _ProvinceBias(43.3188, 11.3307, 40000),
  'Arezzo':          _ProvinceBias(43.4637, 11.8799, 38000),
  'Pisa':            _ProvinceBias(43.7228, 10.4017, 32000),
  'Livorno':         _ProvinceBias(43.5485, 10.3106, 35000),
  'Grosseto':        _ProvinceBias(42.7602, 11.1145, 50000),
  'Lucca':           _ProvinceBias(43.8430, 10.5047, 28000),
  'Massa-Carrara':   _ProvinceBias(44.0353, 10.1414, 25000),
  'Pistoia':         _ProvinceBias(43.9303, 10.9028, 22000),
  'Prato':           _ProvinceBias(43.8777, 11.1023, 18000),
};

// ─── TIPI DI ATTIVITÀ ─────────────────────────────────────────────────────
const Map<String, List<String>> kBusinessTypes = {
  'Ristoranti & Bar':        ['ristorante', 'bar', 'pizzeria', 'trattoria', 'pub', 'locale'],
  'Negozi al dettaglio':     ['negozio', 'bottega', 'shop', 'store', 'punto vendita'],
  'Parrucchieri & Estetica': ['parrucchiere', 'estetista', 'salone', 'barbiere', 'beauty'],
  'Artigiani & Servizi':     ['officina', 'artigiano', 'laboratorio', 'studio'],
  'Supermercati':            ['supermercato', 'alimentari', 'minimarket', 'discount'],
  'Farmacie':                ['farmacia', 'parafarmacia'],
  'Tutte le attività':       ['attività', 'negozio', 'esercizio', 'locale commerciale'],
};

class _ProvinceBias {
  final double lat, lng;
  final int radiusMeters;
  const _ProvinceBias(this.lat, this.lng, this.radiusMeters);
}

// ─── PROGRESS CALLBACK ────────────────────────────────────────────────────
class SearchProgress {
  final int step;
  final String stepName;
  final int found;
  final int verified;
  final String detail;
  const SearchProgress({
    required this.step,
    required this.stepName,
    required this.found,
    required this.verified,
    required this.detail,
  });
}

// ─── KEYWORD DI APERTURA (filtro rigoroso) ─────────────────────────────────
const _openingKeywords = [
  'nuova apertura', 'nuove aperture', 'apre', 'aprirà', 'ha aperto',
  'inaugurazione', 'inaugurato', 'inaugurazione di', 'taglio del nastro',
  'nuovo negozio', 'nuovo ristorante', 'nuovo bar', 'nuovo locale',
  'nuova attività', 'nuova impresa', 'nuova sede',
  'apertura', 'scia', 'inizio attività', 'avvio attività',
  'aperto al pubblico', 'apre i battenti', 'prima apertura',
  'partita iva', 'registrazione impresa', 'nuova partita iva',
  'iscrizione camera di commercio', 'comunicazione apertura',
];

// Keyword NEGATIVE — escludere risultati che le contengono
const _excludeKeywords = [
  'chiude', 'chiusura', 'fallimento', 'fallito', 'sequestro',
  'vendita attività', 'cessione', 'cessazione', 'in vendita',
  'rischia la chiusura', 'crisi', 'licenziamento',
  // GDO — escludere grande distribuzione (non nostri clienti)
  'coop', 'conad', 'esselunga', 'lidl', 'eurospin', 'carrefour',
  'penny market', 'despar', 'md discount', 'aldi', 'pam', 'sigma',
  'simply', 'iper', 'bennet', 'mediaworld', 'unieuro', 'leroy merlin',
  'ikea', 'decathlon', 'primark', 'zara', 'h&m', 'mcdonald',
  'burger king', 'starbucks', 'kfc', 'autogrill', 'eni station',
  'amazon', 'centro commerciale',
];

// ─── SERVICE ───────────────────────────────────────────────────────────────
class MapsService {

  static Future<List<Prospect>> searchBusinesses({
    required String province,
    required String businessTypeKey,
    void Function(SearchProgress progress)? onProgress,
  }) async {
    final bias = kProvince[province];
    final keywords = kBusinessTypes[businessTypeKey];
    if (bias == null || keywords == null) {
      throw Exception('Provincia o tipo attività non validi.');
    }

    final apiUsed = await DatabaseHelper.instance.getApiUsageThisMonth();
    final apiRemaining = kMonthlyApiLimit - apiUsed;

    // ═══ STEP 1: SCOPERTA MULTI-FONTE ═══════════════════════════════════════
    onProgress?.call(SearchProgress(
      step: 1, stepName: '📰 Scoperta multi-fonte',
      found: 0, verified: 0,
      detail: 'Cercando su 4 fonti gratuite…',
    ));

    final rawLeads = <_RawLead>[];

    // 1A: Google News RSS (query multiple e precise)
    onProgress?.call(SearchProgress(
      step: 1, stepName: '📰 Google News',
      found: 0, verified: 0,
      detail: 'Cercando notizie di nuove aperture…',
    ));
    final newsLeads = await _searchGoogleNews(province, keywords, onProgress);
    rawLeads.addAll(newsLeads);

    // 1B: DuckDuckGo HTML search (diverse queries)
    onProgress?.call(SearchProgress(
      step: 1, stepName: '🔍 Ricerca Web',
      found: rawLeads.length, verified: 0,
      detail: 'Cercando su DuckDuckGo…',
    ));
    final webLeads = await _searchDuckDuckGo(province, keywords);
    rawLeads.addAll(webLeads);

    // 1C: Albo Pretorio / SCIA dei comuni toscani
    onProgress?.call(SearchProgress(
      step: 1, stepName: '🏛️ SCIA Comunali',
      found: rawLeads.length, verified: 0,
      detail: 'Cercando SCIA e autorizzazioni…',
    ));
    final sciaLeads = await _searchScia(province, keywords);
    rawLeads.addAll(sciaLeads);

    // 1D: Registroimprese.it ricerca base
    onProgress?.call(SearchProgress(
      step: 1, stepName: '📋 Registro Imprese',
      found: rawLeads.length, verified: 0,
      detail: 'Cercando su registroimprese.it…',
    ));
    final regLeads = await _searchRegistroImprese(province, keywords);
    rawLeads.addAll(regLeads);

    // 1E: Social Media (Facebook/Instagram via Google)
    onProgress?.call(SearchProgress(
      step: 1, stepName: '📱 Social Media',
      found: rawLeads.length, verified: 0,
      detail: 'Cercando su Facebook e Instagram…',
    ));
    final socialLeads = await _searchSocialMedia(province, keywords);
    rawLeads.addAll(socialLeads);

    // 1F: Radar Assunzioni (Offerte di Lavoro)
    onProgress?.call(SearchProgress(
      step: 1, stepName: '🎯 Radar Assunzioni',
      found: rawLeads.length, verified: 0,
      detail: 'Cercando annunci di lavoro per nuove aperture…',
    ));
    final hiringLeads = await _searchHiringSignals(province, keywords);
    rawLeads.addAll(hiringLeads);

    // Deduplica e filtro Blacklist
    final uniqueLeadsList = _deduplicateRawLeads(rawLeads);
    final uniqueLeads = <_RawLead>[];
    
    for (final lead in uniqueLeadsList) {
      final name = _extractBusinessName(lead.title);
      final isBl = await DatabaseHelper.instance.isDuplicateOrBlacklisted(name, province);
      if (!isBl) {
        uniqueLeads.add(lead);
      }
    }

    if (uniqueLeads.isEmpty) {
      throw Exception(
        'Nessuna nuova apertura (non scartata) trovata per\n'
        '"$businessTypeKey" in $province.\n\n'
        'Le 4 fonti (News, Web, SCIA, Registro Imprese)\n'
        'non hanno restituito risultati.\n'
        'Prova un\'altra provincia o tipo di attività.',
      );
    }

    onProgress?.call(SearchProgress(
      step: 1, stepName: '📰 Scoperta completata',
      found: uniqueLeads.length, verified: 0,
      detail: '${uniqueLeads.length} potenziali aperture da ${_countSources(rawLeads)} fonti',
    ));

    // ═══ STEP 2: VERIFICA GOOGLE PLACES ═════════════════════════════════════
    onProgress?.call(SearchProgress(
      step: 2, stepName: '✅ Verifica Google Places',
      found: uniqueLeads.length, verified: 0,
      detail: 'Verificando… (API: $apiUsed/$kMonthlyApiLimit usate)',
    ));

    final verifiedLeads = await _verifyWithPlaces(
      uniqueLeads, province, bias, apiRemaining, onProgress,
    );

    // ═══ STEP 3: AI VALIDATION (Gemini Flash-Lite — gratis) ═════════════════
    onProgress?.call(SearchProgress(
      step: 3, stepName: '🤖 Analisi AI',
      found: uniqueLeads.length, verified: verifiedLeads.length,
      detail: 'L\'AI sta verificando ogni risultato…',
    ));

    final aiValidated = await _aiValidate(
      verifiedLeads, uniqueLeads, province, onProgress,
    );

    // ═══ STEP 4: SCORING URGENZA FINALE ══════════════════════════════════════
    onProgress?.call(SearchProgress(
      step: 4, stepName: '🎯 Classificazione',
      found: uniqueLeads.length, verified: aiValidated.length,
      detail: 'Ordinando per opportunità…',
    ));

    // Ordina per urgenza poi confidence
    aiValidated.sort((a, b) {
      final order = {LeadUrgency.hot: 0, LeadUrgency.warm: 1,
          LeadUrgency.unknown: 2, LeadUrgency.cold: 3};
      final diff = (order[a.urgency] ?? 9) - (order[b.urgency] ?? 9);
      return diff != 0 ? diff : b.confidenceScore.compareTo(a.confidenceScore);
    });

    onProgress?.call(SearchProgress(
      step: 4, stepName: '✨ Completato',
      found: uniqueLeads.length, verified: aiValidated.length,
      detail: '${aiValidated.length} lead verificati dall\'AI!',
    ));

    return aiValidated;
  }

  static Future<int> getApiRemaining() async {
    final used = await DatabaseHelper.instance.getApiUsageThisMonth();
    return kMonthlyApiLimit - used;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3: AI VALIDATION
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<Prospect>> _aiValidate(
    List<Prospect> prospects,
    List<_RawLead> rawLeads,
    String province,
    void Function(SearchProgress)? onProgress,
  ) async {
    final List<Prospect> validated = [];
    
    // Processa in batch di 5
    for (int i = 0; i < prospects.length; i += 5) {
      final end = (i + 5).clamp(0, prospects.length);
      final batch = prospects.sublist(i, end);
      
      onProgress?.call(SearchProgress(
        step: 3, stepName: '🤖 Analisi AI',
        found: prospects.length, verified: validated.length,
        detail: 'Batch ${(i ~/ 5) + 1}/${(prospects.length / 5).ceil()}…',
      ));

      // Prepara items per l'AI
      final items = batch.map((p) {
        final raw = rawLeads.firstWhere(
          (r) => r.title.toLowerCase().contains(p.name.toLowerCase().substring(0, p.name.length.clamp(0, 15))),
          orElse: () => _RawLead(title: p.name, description: '', url: p.sourceUrl ?? '', sourceName: '', province: province, keywordScore: 1, sourceType: p.source ?? 'news'),
        );
        return {'title': p.name, 'description': raw.description};
      }).toList();

      // Analisi AI in batch
      final analyses = await AiService.analyzeBatch(
        items: items, province: province,
      );

      // Applica risultati AI
      for (int j = 0; j < batch.length; j++) {
        final p = batch[j];
        final ai = j < analyses.length ? analyses[j] : AiAnalysis.notAvailable();

        // Filtra: se l'AI dice che NON è una vera apertura con alta confidence, scarta
        if (!ai.isRealOpening && ai.confidenceScore >= 60) {
          continue; // Scartato dall'AI
        }

        // Arricchisci con dati AI
        final urgency = _mapUrgencyFromAi(ai.urgencyLevel);
        final aiConfBoost = ai.isRealOpening ? 20 : 0;
        final newConf = (p.confidenceScore + aiConfBoost + ai.confidenceScore) ~/ 2;

        validated.add(Prospect(
          id: p.id,
          name: ai.businessName.isNotEmpty ? ai.businessName : p.name,
          address: ai.location.isNotEmpty && ai.location.length > 5 ? ai.location : p.address,
          phone: p.phone,
          website: p.website,
          lat: p.lat, lng: p.lng,
          province: p.province,
          businessType: ai.businessType.isNotEmpty ? ai.businessType : p.businessType,
          source: p.source,
          sourceUrl: p.sourceUrl,
          verified: p.verified,
          googlePlaceId: p.googlePlaceId,
          confidenceScore: newConf.clamp(0, 100),
          urgency: urgency != LeadUrgency.unknown ? urgency : _estimateUrgency(p),
          estimatedOpenDate: _extractOpenDate(p),
          notes: ai.reasoning.isNotEmpty ? '🤖 AI: ${ai.reasoning}' : null,
          vatNumber: ai.vatNumber?.isNotEmpty == true ? ai.vatNumber : p.vatNumber,
          ownerName: ai.ownerName?.isNotEmpty == true ? ai.ownerName : p.ownerName,
          email: ai.email?.isNotEmpty == true ? ai.email : p.email,
          extractedPhone: ai.extractedPhone?.isNotEmpty == true ? ai.extractedPhone : p.extractedPhone,
        ));
      }

      // Rate limiting — 15 RPM per Flash-Lite
      if (i + 5 < prospects.length) {
        await Future.delayed(const Duration(milliseconds: 2000));
      }
    }

    return validated;
  }

  static LeadUrgency _mapUrgencyFromAi(String level) {
    switch (level) {
      case 'hot': return LeadUrgency.hot;
      case 'warm': return LeadUrgency.warm;
      case 'cold': return LeadUrgency.cold;
      default: return LeadUrgency.unknown;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FONTE 1A: GOOGLE NEWS RSS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<_RawLead>> _searchGoogleNews(
    String province, List<String> keywords,
    void Function(SearchProgress)? onProgress,
  ) async {
    final List<_RawLead> results = [];

    // Query molto precise e diversificate
    final queries = <String>[
      // Query specifiche per apertura
      '"nuova apertura" "${keywords.first}" "$province"',
      '"inaugurazione" "${keywords.first}" "$province" 2026',
      '"apre" "nuovo ${keywords.first}" "$province"',
      '"nuova attività" "$province" Toscana 2026',
      // Query per SCIA e partita IVA
      '"SCIA" "apertura" "$province" 2026',
      '"nuova partita iva" "$province" ${keywords.first}',
      '"registrazione" "impresa" "$province" "apertura"',
      // Query locali con varianti
      '"apre i battenti" "$province"',
      '"taglio del nastro" "$province" 2026',
    ];

    for (int i = 0; i < queries.length; i++) {
      try {
        onProgress?.call(SearchProgress(
          step: 1, stepName: '📰 Google News',
          found: results.length, verified: 0,
          detail: 'Query ${i + 1}/${queries.length}…',
        ));

        final encoded = Uri.encodeComponent(queries[i]);
        final url = 'https://news.google.com/rss/search?q=$encoded&hl=it&gl=IT&ceid=IT:it';

        final response = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
          'Accept': 'application/rss+xml, text/xml',
        }).timeout(const Duration(seconds: 12));

        if (response.statusCode == 200) {
          results.addAll(_parseNewsRss(response.body, province, 'news'));
        }
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) { continue; }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FONTE 1B: DUCKDUCKGO HTML SEARCH
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<_RawLead>> _searchDuckDuckGo(
    String province, List<String> keywords,
  ) async {
    final List<_RawLead> results = [];
    final queries = [
      'nuova apertura ${keywords.first} $province 2026',
      'inaugurazione ${keywords.first} $province Toscana',
      'SCIA apertura attività $province',
    ];

    for (final query in queries) {
      try {
        final encoded = Uri.encodeComponent(query);
        final url = 'https://html.duckduckgo.com/html/?q=$encoded';
        final response = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        }).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          results.addAll(_parseDuckDuckGoHtml(response.body, province));
        }
        await Future.delayed(const Duration(milliseconds: 600));
      } catch (_) { continue; }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FONTE 1C: SCIA / ALBO PRETORIO COMUNALI
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<_RawLead>> _searchScia(
    String province, List<String> keywords,
  ) async {
    final List<_RawLead> results = [];

    // Cerca su Google News per SCIA specifiche
    final queries = [
      '"albo pretorio" "SCIA" "$province" apertura attività commerciale',
      '"SUAP" "$province" "autorizzazione" apertura',
      '"segnalazione certificata" "inizio attività" "$province" 2026',
    ];

    for (final query in queries) {
      try {
        final encoded = Uri.encodeComponent(query);
        final url = 'https://news.google.com/rss/search?q=$encoded&hl=it&gl=IT&ceid=IT:it';
        final response = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        }).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          results.addAll(_parseNewsRss(response.body, province, 'scia'));
        }
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) { continue; }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FONTE 1D: REGISTRO IMPRESE (ricerca gratis)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<_RawLead>> _searchRegistroImprese(
    String province, List<String> keywords,
  ) async {
    final List<_RawLead> results = [];

    // Cerca su Google News notizie che menzionano registro imprese + aperture
    final queries = [
      '"registro imprese" "nuova iscrizione" "$province" ${keywords.first}',
      '"camera di commercio" "nuova attività" "$province" 2026',
      '"apertura partita iva" "$province" ${keywords.first} 2026',
    ];

    for (final query in queries) {
      try {
        final encoded = Uri.encodeComponent(query);
        final url = 'https://news.google.com/rss/search?q=$encoded&hl=it&gl=IT&ceid=IT:it';
        final response = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        }).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          results.addAll(_parseNewsRss(response.body, province, 'registro'));
        }
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) { continue; }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FONTE 1E: SOCIAL MEDIA (Facebook/Instagram via Google)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<_RawLead>> _searchSocialMedia(
    String province, List<String> keywords,
  ) async {
    final List<_RawLead> results = [];

    // Cerca su Google News riferimenti a post social su nuove aperture
    final queries = [
      'site:facebook.com "nuova apertura" "$province" ${keywords.first}',
      'site:instagram.com "apertura" "$province" ${keywords.first}',
      '"facebook" "inaugurazione" "$province" ${keywords.first} 2026',
      '"instagram" "nuovo ${keywords.first}" "$province" Toscana',
      // Post locali e pagine comunali
      '"facebook.com" "nuova attività" "$province" registratore cassa',
    ];

    for (final query in queries) {
      try {
        final encoded = Uri.encodeComponent(query);
        final url = 'https://news.google.com/rss/search?q=$encoded&hl=it&gl=IT&ceid=IT:it';
        final response = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        }).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          results.addAll(_parseNewsRss(response.body, province, 'social'));
        }
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) { continue; }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FONTE 1F: RADAR ASSUNZIONI (Offerte Lavoro)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<_RawLead>> _searchHiringSignals(
    String province, List<String> keywords,
  ) async {
    final List<_RawLead> results = [];

    // Query focalizzate su assunzioni prima dell'apertura (opportunità hot)
    final queries = [
      '"cerchiamo personale" "nuova apertura" "$province" ${keywords.first}',
      '"assunzioni" "prossima apertura" "$province" ${keywords.first}',
      'site:subito.it "camerieri" OR "commessi" "apertura" "$province"',
      'site:it.indeed.com "nuova apertura" "$province" ${keywords.first}',
      'site:linkedin.com/jobs "store manager" "nuovo" "$province"',
    ];

    for (final query in queries) {
      try {
        final encoded = Uri.encodeComponent(query);
        final url = 'https://news.google.com/rss/search?q=$encoded&hl=it&gl=IT&ceid=IT:it';
        final response = await http.get(Uri.parse(url), headers: {
          'User-Agent': 'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36',
        }).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          results.addAll(_parseNewsRss(response.body, province, 'hiring'));
        }
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (_) { continue; }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 2: VERIFICA GOOGLE PLACES
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<Prospect>> _verifyWithPlaces(
    List<_RawLead> rawLeads,
    String province,
    _ProvinceBias bias,
    int apiRemaining,
    void Function(SearchProgress)? onProgress,
  ) async {
    final List<Prospect> verified = [];
    int apiCallsMade = 0;
    final maxVerify = apiRemaining > 50 ? rawLeads.length.clamp(0, 25) : 0;

    for (int i = 0; i < rawLeads.length; i++) {
      final lead = rawLeads[i];
      bool isVerified = false;
      String address = 'Provincia di $province, Toscana';
      String? phone, website, placeId, businessType;
      double lat = bias.lat + (i * 0.002);
      double lng = bias.lng + (i * 0.002);

      if (i < maxVerify && apiRemaining - apiCallsMade > 0) {
        try {
          onProgress?.call(SearchProgress(
            step: 2, stepName: '✅ Verifica',
            found: rawLeads.length, verified: verified.where((v) => v.verified).length,
            detail: 'Verifica ${i + 1}/$maxVerify…',
          ));

          final searchQuery = _extractBusinessName(lead.title) + ' $province';
          final placeData = await _searchPlace(searchQuery, bias);
          apiCallsMade++;
          await DatabaseHelper.instance.incrementApiUsage();

          if (placeData != null) {
            isVerified = true;
            address = placeData['address'] ?? address;
            phone = placeData['phone'];
            website = placeData['website'];
            lat = placeData['lat'] ?? lat;
            lng = placeData['lng'] ?? lng;
            placeId = placeData['placeId'];
            businessType = placeData['type'];
          }
          await Future.delayed(const Duration(milliseconds: 250));
        } catch (_) {}
      }

      // Cross-validazione: se trovato da più fonti, confidence più alta
      final crossSourceCount = rawLeads.where((r) =>
          r.title.toLowerCase().contains(lead.title.toLowerCase().substring(0, lead.title.length.clamp(0, 20)))
      ).length;

      verified.add(Prospect(
        name: _extractBusinessName(lead.title),
        address: address,
        phone: phone,
        website: website,
        lat: lat,
        lng: lng,
        province: province,
        businessType: businessType ?? lead.sourceName,
        source: lead.sourceType,
        sourceUrl: lead.url,
        verified: isVerified,
        googlePlaceId: placeId ?? '${lead.sourceType}_${lead.url.hashCode}',
        confidenceScore: _calculateConfidence(lead, isVerified, crossSourceCount),
      ));
    }

    return verified;
  }

  static Future<Map<String, dynamic>?> _searchPlace(
    String query, _ProvinceBias bias,
  ) async {
    const baseUrl = 'https://places.googleapis.com/v1/places:searchText';
    const fieldMask = 'places.id,places.displayName,places.formattedAddress,'
        'places.internationalPhoneNumber,places.websiteUri,'
        'places.location,places.types';

    final body = {
      'textQuery': query,
      'languageCode': 'it',
      'regionCode': 'IT',
      'locationBias': {
        'circle': {
          'center': {'latitude': bias.lat, 'longitude': bias.lng},
          'radius': bias.radiusMeters.toDouble(),
        }
      },
      'pageSize': 1,
    };

    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': kGoogleApiKey,
        'X-Goog-FieldMask': fieldMask,
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body);
    final places = data['places'] as List<dynamic>? ?? [];
    if (places.isEmpty) return null;

    final place = places.first;
    final location = place['location'];
    final types = (place['types'] as List<dynamic>?)?.cast<String>() ?? [];

    return {
      'placeId': place['id'],
      'address': place['formattedAddress'],
      'phone': place['internationalPhoneNumber'],
      'website': place['websiteUri'],
      'lat': (location?['latitude'] as num?)?.toDouble(),
      'lng': (location?['longitude'] as num?)?.toDouble(),
      'type': types.isNotEmpty ? types.first : null,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STEP 3: URGENCY SCORING
  // ═══════════════════════════════════════════════════════════════════════════

  static List<Prospect> _scoreUrgency(List<Prospect> prospects) {
    return prospects.map((p) {
      final urgency = _estimateUrgency(p);
      final openDate = _extractOpenDate(p);
      return Prospect(
        id: p.id, name: p.name, address: p.address,
        phone: p.phone, website: p.website,
        lat: p.lat, lng: p.lng, province: p.province,
        businessType: p.businessType, source: p.source,
        sourceUrl: p.sourceUrl, verified: p.verified,
        googlePlaceId: p.googlePlaceId,
        confidenceScore: p.confidenceScore,
        urgency: urgency,
        estimatedOpenDate: openDate,
      );
    }).toList();
  }

  static LeadUrgency _estimateUrgency(Prospect p) {
    final text = '${p.name} ${p.sourceUrl ?? ""}'.toLowerCase();

    // GIÀ APERTO (🔴 rosso)
    final past = ['ha aperto', 'inaugurato', 'è stato inaugurato',
        'aperto al pubblico', 'ha inaugurato', 'già aperto', 'ieri ha aperto'];
    // IMMINENTE (🟡 giallo)
    final soon = ['aprirà', 'apre domani', 'apre questa settimana',
        'prossima apertura', 'inaugurazione prevista', 'tra pochi giorni',
        'la prossima settimana', 'apre sabato', 'apre venerdì'];
    // FUTURO (🟢 verde — OPPORTUNITÀ!)
    final future = ['in progetto', 'progetto di apertura', 'prevista per',
        'entro la fine', 'nei prossimi mesi', 'nuovo progetto',
        'in fase di ristrutturazione', 'lavori in corso', 'cantiere',
        'autorizzazione', 'SCIA', 'richiesta apertura', 'permesso',
        'partita iva', 'registrazione', 'comunicazione inizio'];

    for (final kw in past) { if (text.contains(kw)) return LeadUrgency.cold; }
    for (final kw in soon) { if (text.contains(kw)) return LeadUrgency.warm; }
    for (final kw in future) { if (text.contains(kw)) return LeadUrgency.hot; }
    return LeadUrgency.unknown;
  }

  static DateTime? _extractOpenDate(Prospect p) {
    final text = p.name.toLowerCase();
    final months = {'gennaio':1,'febbraio':2,'marzo':3,'aprile':4,
        'maggio':5,'giugno':6,'luglio':7,'agosto':8,
        'settembre':9,'ottobre':10,'novembre':11,'dicembre':12};

    for (final entry in months.entries) {
      final pattern = RegExp('(\\d{1,2})\\s+${entry.key}', caseSensitive: false);
      final match = pattern.firstMatch(text);
      if (match != null) {
        final day = int.tryParse(match.group(1) ?? '');
        if (day != null && day >= 1 && day <= 31) {
          return DateTime(DateTime.now().year, entry.value, day);
        }
      }
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PARSING
  // ═══════════════════════════════════════════════════════════════════════════

  static List<_RawLead> _parseNewsRss(String xml, String province, String sourceType) {
    final List<_RawLead> results = [];
    final itemRegex = RegExp(r'<item>(.*?)</item>', dotAll: true);

    for (final item in itemRegex.allMatches(xml)) {
      final content = item.group(1) ?? '';
      final title = _cleanHtml(_extractTag(content, 'title'));
      final link = _extractTag(content, 'link');
      final description = _cleanHtml(_extractTag(content, 'description'));
      final pubDate = _extractTag(content, 'pubDate');
      final sourceName = _cleanHtml(_extractTag(content, 'source'));

      if (title.isEmpty) continue;

      final combined = '$title $description'.toLowerCase();

      // FILTRO RIGOROSO: deve contenere keyword di apertura
      final matchCount = _countOpeningKeywords(combined);
      if (matchCount < 1) continue;

      // FILTRO NEGATIVO: escludere chiusure, fallimenti, etc
      if (_containsExcludeKeyword(combined)) continue;

      DateTime? newsDate;
      if (pubDate.isNotEmpty) newsDate = _parseRssDate(pubDate);

      results.add(_RawLead(
        title: title.length > 120 ? '${title.substring(0, 117)}…' : title,
        description: description,
        url: link,
        sourceName: sourceName.isNotEmpty ? sourceName : 'Notizia',
        publishDate: newsDate,
        province: province,
        keywordScore: matchCount,
        sourceType: sourceType,
      ));
    }
    return results;
  }

  static List<_RawLead> _parseDuckDuckGoHtml(String html, String province) {
    final List<_RawLead> results = [];
    final resultRegex = RegExp(
      r'class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)</a>.*?class="result__snippet"[^>]*>(.*?)</td>',
      dotAll: true,
    );

    for (final match in resultRegex.allMatches(html)) {
      final url = _cleanHtml(match.group(1) ?? '');
      final title = _cleanHtml(match.group(2) ?? '');
      final snippet = _cleanHtml(match.group(3) ?? '');

      if (title.isEmpty) continue;

      final combined = '$title $snippet'.toLowerCase();
      final matchCount = _countOpeningKeywords(combined);
      if (matchCount < 1) continue;
      if (_containsExcludeKeyword(combined)) continue;

      results.add(_RawLead(
        title: title.length > 120 ? '${title.substring(0, 117)}…' : title,
        description: snippet,
        url: url.startsWith('//') ? 'https:$url' : url,
        sourceName: 'Web',
        province: province,
        keywordScore: matchCount,
        sourceType: 'web',
      ));
    }
    return results;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITY
  // ═══════════════════════════════════════════════════════════════════════════

  static int _countOpeningKeywords(String text) {
    return _openingKeywords.where((kw) => text.contains(kw)).length;
  }

  static bool _containsExcludeKeyword(String text) {
    return _excludeKeywords.any((kw) => text.contains(kw));
  }

  static int _calculateConfidence(_RawLead lead, bool verified, int crossCount) {
    int score = 15;
    score += lead.keywordScore * 12;
    if (verified) score += 30;
    if (crossCount > 1) score += crossCount * 8; // cross-validazione
    if (lead.sourceType == 'scia' || lead.sourceType == 'registro') score += 10; // fonti ufficiali
    if (lead.publishDate != null) {
      final daysAgo = DateTime.now().difference(lead.publishDate!).inDays;
      if (daysAgo < 7) score += 15;
      else if (daysAgo < 30) score += 8;
    }
    return score.clamp(0, 100);
  }

  static int _countSources(List<_RawLead> leads) {
    return leads.map((l) => l.sourceType).toSet().length;
  }

  static String _extractBusinessName(String title) {
    var name = title;
    final prefixes = [
      RegExp(r'^(\w+),?\s+(apre|inaugura|arriva)\s+(il|la|un|una)?\s*nuovo?\s*', caseSensitive: false),
      RegExp(r'^(nuova apertura|inaugurazione|apre)\s*:?\s*', caseSensitive: false),
    ];
    for (final p in prefixes) { name = name.replaceFirst(p, ''); }
    return name.isEmpty ? title : name;
  }

  static String _extractTag(String content, String tag) {
    final cdataRegex = RegExp('<$tag[^>]*><!\\[CDATA\\[(.*?)\\]\\]></$tag>', dotAll: true);
    final cdataMatch = cdataRegex.firstMatch(content);
    if (cdataMatch != null) return cdataMatch.group(1) ?? '';
    final regex = RegExp('<$tag[^>]*>(.*?)</$tag>', dotAll: true);
    return regex.firstMatch(content)?.group(1) ?? '';
  }

  static String _cleanHtml(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&').replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>').replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'").replaceAll('&apos;', "'")
        .replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static DateTime? _parseRssDate(String dateStr) {
    try { return DateTime.parse(dateStr); } catch (_) {}
    final months = {'Jan':1,'Feb':2,'Mar':3,'Apr':4,'May':5,'Jun':6,
        'Jul':7,'Aug':8,'Sep':9,'Oct':10,'Nov':11,'Dec':12};
    final parts = dateStr.split(' ');
    if (parts.length >= 5) {
      final day = int.tryParse(parts[1]);
      final month = months[parts[2]];
      final year = int.tryParse(parts[3]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
    return null;
  }

  static List<_RawLead> _deduplicateRawLeads(List<_RawLead> leads) {
    final seen = <String>{};
    return leads.where((l) {
      final key = l.title.toLowerCase().substring(0, l.title.length.clamp(0, 35));
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }
}

class _RawLead {
  final String title, description, url, sourceName, sourceType, province;
  final DateTime? publishDate;
  final int keywordScore;

  const _RawLead({
    required this.title, required this.description,
    required this.url, required this.sourceName,
    this.publishDate, required this.province,
    required this.keywordScore, required this.sourceType,
  });
}
