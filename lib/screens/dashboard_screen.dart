// lib/screens/dashboard_screen.dart — v6

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/prospect.dart';
import '../services/updater_service.dart';
import '../services/maps_service.dart';
import 'changelog_screen.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onRefresh;
  const DashboardScreen({super.key, this.onRefresh});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;
  Map<String, dynamic>? _pendingUpdate;

  @override
  void initState() {
    super.initState();
    _load();
    _checkUpdates();
  }

  Future<void> _checkUpdates() async {
    final update = await UpdaterService.fetchLatestUpdate();
    if (update != null) {
      if (mounted) {
        setState(() {
          _pendingUpdate = update;
        });
      }
      // Trigger push notification simulation
      await UpdaterService.triggerPushNotification(
        'Aggiornamento Disponibile!',
        'La versione ${update['versionName']} è pronta per il download. Clicca sulla campanella per installare.',
      );
    }
  }

  Future<void> _load() async {
    final stats = await DatabaseHelper.instance.getDashboardStats();
    if (mounted) setState(() { _stats = stats; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          // NOTIFICATION BELL
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_none, size: 26),
                if (_pendingUpdate != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 10,
                        minHeight: 10,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Notifiche',
            onPressed: () {
              if (_pendingUpdate != null) {
                UpdaterService.showUpdateDialog(context, _pendingUpdate!);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nessuna notifica pendente.')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.history_edu, color: Colors.blueAccent),
            tooltip: 'Novità & Aggiornamenti',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangelogScreen()));
            },
          ),
          IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  // ── KPI ──
                  _buildKpiRow(),
                  const SizedBox(height: 12),

                  // ── API Budget ──
                  _buildApiCredits(),
                  const SizedBox(height: 12),

                  // ── Conversion Funnel ──
                  _buildFunnel(),
                  const SizedBox(height: 12),

                  // ── Weekly Activity ──
                  _buildWeeklyCard(),
                  const SizedBox(height: 12),

                  // ── Follow-up Alert ──
                  _buildFollowUpAlert(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  Widget _buildKpiRow() {
    final total = _stats['total'] ?? 0;
    final followUp = _stats['needFollowUp'] ?? 0;
    final newWeek = _stats['newThisWeek'] ?? 0;
    final won = (_stats['statusStats'] as Map<String, int>?)?['chiuso_vinto'] ?? 0;

    return Row(children: [
      _kpiCard('📊', '$total', 'Lead totali', const Color(0xFF42A5F5)),
      const SizedBox(width: 8),
      _kpiCard('🆕', '$newWeek', 'Questa settimana', const Color(0xFF4CAF50)),
      const SizedBox(width: 8),
      _kpiCard('⏰', '$followUp', 'Da seguire', Colors.orange),
      const SizedBox(width: 8),
      _kpiCard('🏆', '$won', 'Acquisiti', Colors.amber),
    ]);
  }

  Widget _kpiCard(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white24, fontSize: 9)),
        ]),
      ),
    );
  }

  Widget _buildFunnel() {
    final stats = (_stats['statusStats'] as Map<String, int>?) ?? {};
    final total = _stats['total'] ?? 1;

    final steps = [
      ('Nuovi', stats['nuovo'] ?? 0, const Color(0xFFE53935)),
      ('Da visitare', stats['da_visitare'] ?? 0, const Color(0xFFFF6F00)),
      ('Visitati', stats['visitato'] ?? 0, const Color(0xFF1565C0)),
      ('Interessati', stats['interessato'] ?? 0, const Color(0xFF6A1B9A)),
      ('Proposta', stats['proposta'] ?? 0, const Color(0xFF00838F)),
      ('Acquisiti ✓', stats['chiuso_vinto'] ?? 0, const Color(0xFF2E7D32)),
      ('Persi', stats['chiuso_perso'] ?? 0, Colors.grey),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 Funnel di Conversione',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ...steps.map((s) {
            final pct = total > 0 ? (s.$2 / total * 100).toStringAsFixed(0) : '0';
            final barWidth = total > 0 ? s.$2 / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    SizedBox(width: 90, child: Text(s.$1,
                        style: const TextStyle(fontSize: 11, color: Colors.white38))),
                    Expanded(
                      child: Stack(children: [
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(9)),
                        ),
                        FractionallySizedBox(
                          widthFactor: barWidth.clamp(0.02, 1.0),
                          child: Container(
                            height: 18,
                            decoration: BoxDecoration(
                              color: s.$3.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: s.$3.withOpacity(0.5))),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 35, child: Text('${s.$2}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: s.$3),
                        textAlign: TextAlign.right)),
                    SizedBox(width: 30, child: Text('$pct%',
                        style: const TextStyle(color: Colors.white24, fontSize: 10),
                        textAlign: TextAlign.right)),
                  ]),
                ],
              ),
            );
          }),
          // Conversion rate
          if ((_stats['total'] ?? 0) > 0) ...[
            const Divider(color: Colors.white10, height: 16),
            Row(children: [
              const Text('Tasso conversione: ', style: TextStyle(color: Colors.white30, fontSize: 11)),
              Text(
                '${(((stats['chiuso_vinto'] ?? 0) / (_stats['total'] ?? 1)) * 100).toStringAsFixed(1)}%',
                style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildWeeklyCard() {
    final newWeek = _stats['newThisWeek'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFF4CAF50).withOpacity(0.12),
            borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('📅', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Questa settimana', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text('$newWeek nuovi lead trovati', style: const TextStyle(color: Colors.white30, fontSize: 11)),
          ],
        )),
        Text('$newWeek', style: const TextStyle(
            color: Color(0xFF4CAF50), fontSize: 28, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildFollowUpAlert() {
    final followUp = _stats['needFollowUp'] ?? 0;
    if (followUp == 0) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14)),
        child: const Row(children: [
          Text('✅', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Text('Nessun follow-up urgente!', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
        ]),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.2))),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12)),
          child: const Center(child: Text('⏰', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Follow-up necessari', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 2),
            Text('$followUp lead da ricontattare (>3 giorni fa)',
                style: const TextStyle(color: Colors.white30, fontSize: 11)),
          ],
        )),
        Text('$followUp', style: const TextStyle(
            color: Colors.orange, fontSize: 28, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // API CREDITS WIDGET
  // ──────────────────────────────────────────────────────────────────────

  Widget _buildApiCredits() {
    return FutureBuilder<List<int>>(
      future: Future.wait([
        DatabaseHelper.instance.getApiUsageThisMonth(),
        DatabaseHelper.instance.getAiUsageToday(),
      ]),
      builder: (context, snapshot) {
        final placesUsed = snapshot.data?[0] ?? 0;
        final aiUsed = snapshot.data?[1] ?? 0;
        const placesMax = kMonthlyApiLimit;
        const aiMax = 1000;

        final placesPercent = (placesUsed / placesMax).clamp(0.0, 1.0);
        final aiPercent = (aiUsed / aiMax).clamp(0.0, 1.0);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2333),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(children: [
                Icon(Icons.speed, color: Colors.blueAccent, size: 20),
                SizedBox(width: 8),
                Text('Budget API', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 16),

              // Google Places
              _apiBar(
                label: '🗺️ Google Places',
                used: placesUsed,
                max: placesMax,
                percent: placesPercent,
                subtitle: 'Mensile (200 USD free tier)',
              ),
              const SizedBox(height: 12),

              // Gemini AI
              _apiBar(
                label: '🧠 Gemini AI',
                used: aiUsed,
                max: aiMax,
                percent: aiPercent,
                subtitle: 'Giornaliero (reset ogni giorno)',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _apiBar({
    required String label,
    required int used,
    required int max,
    required double percent,
    required String subtitle,
  }) {
    final color = percent > 0.8
        ? Colors.redAccent
        : percent > 0.5
            ? Colors.orangeAccent
            : const Color(0xFF4CAF50);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text('$used / $max', style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.white10,
            color: color,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10)),
      ],
    );
  }
}

