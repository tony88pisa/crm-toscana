import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({super.key});

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen> {
  String _currentVersion = 'Caricamento...';

  final List<Map<String, dynamic>> _releases = [
    {
      'version': 'v15',
      'date': 'Marzo 2026',
      'title': 'AI Potenziata & Budget API',
      'notes': [
        'Dashboard Budget API: monitora crediti Google Places e Gemini in tempo reale.',
        'Ricerca Contatti Approfondita: l\'AI cerca telefono e titolare per ogni lead.',
        'Nuove keyword di ricerca per accuratezza massima su subentri e nuove gestioni.',
        'Limite API corretto a 5.800 chiamate/mese (free tier reale).',
      ],
    },
    {
      'version': 'v14',
      'date': 'Marzo 2026',
      'title': 'Stabilità OTA & Sicurezza',
      'notes': [
        'Nuovo motore di aggiornamento professionale (OtaUpdate).',
        'Verifica integrità pacchetto tramite Checksum SHA256.',
        'Fix compatibilità Android 11-14 (Restrizioni Visibilità).',
        'Barra di avanzamento download reale (0-100%).',
      ],
    },
    {
      'version': 'v12',
      'date': 'Marzo 2026',
      'title': 'Target B2B e AI Ottimizzata',
      'notes': [
        'Intelligenza Artificiale ricalibrata per favorire botteghe, bar, ristoranti e piccoli artigiani.',
        'Migliorate le query di ricerca per cercare "nuove gestioni", "subentri" e botteghe di paese.',
        'Filtro anti-corporate potenziato (scarta bando, appalti, Esselunga, Coop, ecc).',
      ],
    },
    {
      'version': 'v11',
      'date': 'Marzo 2026',
      'title': 'Intelligenza, Contatti & Storico',
      'notes': [
        'Aggiunta schermata Novità e Aggiornamenti.',
        'Tasto "Cerca su Google" se manca il referente o il telefono.',
        'Migliorata la stabilità dell\'Intelligenza Artificiale (anti-crash).',
      ],
    },
    {
      'version': 'v10',
      'date': 'Marzo 2026',
      'title': 'Sistema OTA in Cloud',
      'notes': [
        'Aggiornamenti automatici senza passare dal Play Store.',
        'Sistema di distribuzione GitHub integrato.',
      ],
    },
    {
      'version': 'v9',
      'date': 'Marzo 2026',
      'title': 'Motore OTA Base',
      'notes': [
        'Infrastruttura per download e installazione APK dall\'app.',
      ],
    },
    {
      'version': 'v8',
      'date': 'Marzo 2026',
      'title': 'Precisione Totale & Contatti Reali',
      'notes': [
        'Rimossi i valori in € fittizi (Pipeline/Won).Solo Lead Reali.',
        'Estrazione AI chirurgica di Nome Titolare, Email e Cellulare.',
        'Nuove Regole Paranoiche AI per ignorare finti ri-allestimenti.',
        'Mappa migliorata per indirizzi precisi.',
      ],
    },
    {
      'version': 'v7',
      'date': 'Marzo 2026',
      'title': 'Radar Assunzioni & Blacklist',
      'notes': [
        'Tasto per estrarre la P.IVA.',
        'Nuovo canale "Assunzioni" per scovare nuove aperture.',
        'Bottone Blacklist contro i falsi positivi.',
      ],
    },
    {
      'version': 'v6',
      'date': 'Marzo 2026',
      'title': 'Mega Update: Funnel & WhatsApp',
      'notes': [
        'Nuova Dashboard a imbuto (Funnel di Conversione).',
        'Integrazione pulsante Whatsapp nel dettaglio.',
      ],
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _currentVersion = '${info.version}+${info.buildNumber}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      appBar: AppBar(
        title: const Text('Novità & Aggiornamenti', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF141A29),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Banner Versione Attuale
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A237E), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.system_update, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                const Text('Versione Attuale', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  _currentVersion,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _releases.length,
              itemBuilder: (context, index) {
                final release = _releases[index];
                final isLatest = index == 0;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2333),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isLatest ? Colors.blueAccent.withOpacity(0.5) : Colors.white10,
                      width: isLatest ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isLatest ? Colors.blueAccent.withOpacity(0.1) : Colors.white.withOpacity(0.02),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(release['version'], style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                if (isLatest) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                    child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ],
                            ),
                            Text(release['date'], style: const TextStyle(color: Colors.white54, fontSize: 13)),
                          ],
                        ),
                      ),
                      
                      // Body Card
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(release['title'], style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 12),
                            ...(release['notes'] as List<String>).map((note) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: Colors.white54, fontSize: 14)),
                                  Expanded(child: Text(note, style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4))),
                                ],
                              ),
                            )).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
