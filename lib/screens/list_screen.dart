// lib/screens/list_screen.dart — v5 Premium

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/prospect.dart';
import '../services/location_service.dart';
import '../services/csv_service.dart';
import 'prospect_detail_screen.dart';

class ListScreen extends StatefulWidget {
  final VoidCallback? onRefresh;
  const ListScreen({super.key, this.onRefresh});

  @override
  State<ListScreen> createState() => _ListScreenState();
}

class _ListScreenState extends State<ListScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  List<Prospect> _all = [];
  bool _loading = true;

  // Filtri
  LeadUrgency? _urgencyFilter;
  ProspectStatus? _statusFilter;
  bool _onlyVerified = false;
  bool _sortByConfidence = true;

  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await LocationService.instance.getCurrentPosition();
    final data = await DatabaseHelper.instance.getAllProspects(
      status: _statusFilter,
      urgency: _urgencyFilter,
    );

    if (_sortByConfidence) {
      data.sort((a, b) => b.confidenceScore.compareTo(a.confidenceScore));
    } else {
      LocationService.instance.sortByDistance(data);
    }

    if (mounted) {
      setState(() { _all = data; _loading = false; });
    }
    widget.onRefresh?.call();
  }

  List<Prospect> get _verified =>
      _applySearch(_all.where((p) => p.verified || p.confidenceScore >= 50).toList());
  List<Prospect> get _news =>
      _applySearch(_all.where((p) => !p.verified && p.confidenceScore < 50).toList());

  List<Prospect> _applySearch(List<Prospect> list) {
    if (_searchQuery.isEmpty && !_onlyVerified) return list;
    return list.where((p) {
      if (_onlyVerified && !p.verified) return false;
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return p.name.toLowerCase().contains(q) ||
             p.address.toLowerCase().contains(q) ||
             (p.phone?.contains(q) ?? false);
    }).toList();
  }

  Future<void> _deleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
          SizedBox(width: 8),
          Text('Cancella tutto', style: TextStyle(fontSize: 16)),
        ]),
        content: Text(
          'Eliminare tutti i ${_all.length} lead?\nQuesta azione è irreversibile.',
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Elimina tutto'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await DatabaseHelper.instance.deleteAll();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final total = _all.length;
    final hot = _all.where((p) => p.urgency == LeadUrgency.hot).length;
    final warm = _all.where((p) => p.urgency == LeadUrgency.warm).length;
    final cold = _all.where((p) => p.urgency == LeadUrgency.cold).length;

    return Scaffold(
      appBar: AppBar(
        title: Text('Lead ($total)'),
        actions: [
          IconButton(
            icon: Icon(_sortByConfidence ? Icons.psychology : Icons.near_me, size: 20),
            tooltip: _sortByConfidence ? 'Ordine: AI score' : 'Ordine: distanza',
            onPressed: () { setState(() => _sortByConfidence = !_sortByConfidence); _load(); },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            color: const Color(0xFF1C2333),
            onSelected: (v) {
              if (v == 'delete_all') _deleteAll();
              if (v == 'refresh') _load();
              if (v == 'export') _export();
              if (v == 'verified_only') setState(() { _onlyVerified = !_onlyVerified; });
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'refresh', child: Row(children: [
                Icon(Icons.refresh, size: 16, color: Colors.white54), SizedBox(width: 10), Text('Aggiorna'),
              ])),
              const PopupMenuItem(value: 'export', child: Row(children: [
                Icon(Icons.download, size: 16, color: Colors.white54), SizedBox(width: 10), Text('Esporta CSV'),
              ])),
              PopupMenuItem(value: 'verified_only', child: Row(children: [
                Icon(_onlyVerified ? Icons.check_box : Icons.check_box_outline_blank,
                    size: 16, color: const Color(0xFF4CAF50)),
                const SizedBox(width: 10),
                const Text('Solo verificati'),
              ])),
              PopupMenuItem(value: 'delete_all', child: Row(children: [
                Icon(Icons.delete_forever, size: 16, color: Colors.red.shade300),
                const SizedBox(width: 10),
                Text('Cancella tutto', style: TextStyle(color: Colors.red.shade300)),
              ])),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Urgency filter chips ──
          _buildUrgencyFilters(hot, warm, cold),
          // ── Search bar ──
          _buildSearchBar(),
          // ── Status filter chips ──
          _buildStatusFilters(),
          // ── Tab bar ──
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1C2333), width: 1)),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicatorColor: const Color(0xFF4CAF50),
              indicatorWeight: 2,
              labelColor: const Color(0xFF4CAF50),
              unselectedLabelColor: Colors.white30,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: '✅ Verificati (${_verified.length})'),
                Tab(text: '📰 Notizie (${_news.length})'),
              ],
            ),
          ),
          // ── Lista ──
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50)))
                : TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildListView(_verified, isVerified: true),
                      _buildListView(_news, isVerified: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ── URGENCY FILTERS (🟢🟡🔴) ──

  Widget _buildUrgencyFilters(int hot, int warm, int cold) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Row(
        children: [
          _urgencyChip(LeadUrgency.hot, '🟢', 'Caldi', hot, const Color(0xFF4CAF50)),
          const SizedBox(width: 6),
          _urgencyChip(LeadUrgency.warm, '🟡', 'Tiepidi', warm, const Color(0xFFF9A825)),
          const SizedBox(width: 6),
          _urgencyChip(LeadUrgency.cold, '🔴', 'Freddi', cold, const Color(0xFFE53935)),
          const SizedBox(width: 6),
          _urgencyChip(null, '📊', 'Tutti', _all.length, Colors.white38),
        ],
      ),
    );
  }

  Widget _urgencyChip(LeadUrgency? urgency, String emoji, String label, int count, Color color) {
    final selected = _urgencyFilter == urgency;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _urgencyFilter = urgency); _load(); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? color.withOpacity(0.4) : Colors.transparent),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 3),
                  Text('$count', style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16,
                    color: selected ? color : Colors.white38,
                  )),
                ],
              ),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(
                fontSize: 9, color: selected ? color : Colors.white24,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // ── SEARCH BAR ──

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: SizedBox(
        height: 38,
        child: TextField(
          controller: _searchCtrl,
          onChanged: (q) => setState(() => _searchQuery = q),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Cerca…',
            prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white24),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); },
                    child: const Icon(Icons.clear, size: 16, color: Colors.white24))
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }

  // ── STATUS FILTERS ──

  Widget _buildStatusFilters() {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          _statusChip(null, 'Tutti'),
          ...ProspectStatus.values.map((s) => _statusChip(s, s.label)),
        ],
      ),
    );
  }

  Widget _statusChip(ProspectStatus? status, String label) {
    final selected = _statusFilter == status;
    final color = status != null ? Color(status.colorValue) : Colors.white38;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: GestureDetector(
        onTap: () { setState(() => _statusFilter = status); _load(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: selected ? color.withOpacity(0.4) : Colors.white10),
          ),
          child: Text(label, style: TextStyle(
            fontSize: 11, color: selected ? color : Colors.white30,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          )),
        ),
      ),
    );
  }

  // ── LIST VIEW ──

  Widget _buildListView(List<Prospect> items, {required bool isVerified}) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isVerified ? Icons.verified_outlined : Icons.article_outlined,
                size: 48, color: Colors.white.withOpacity(0.08)),
            const SizedBox(height: 12),
            Text(
              isVerified
                  ? 'Nessun lead verificato.\nAvvia una ricerca per trovarne!'
                  : 'Nessuna notizia trovata.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white24, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 80),
        itemCount: items.length,
        itemBuilder: (_, i) => _LeadCard(
          prospect: items[i],
          onTap: () => _openDetail(items[i]),
          onStatusChanged: (s) => _quickStatus(items[i], s),
        ),
      ),
    );
  }

  void _openDetail(Prospect p) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProspectDetailScreen(prospect: p)));
    _load();
  }

  Future<void> _quickStatus(Prospect p, ProspectStatus s) async {
    await DatabaseHelper.instance.updateStatus(p.id!, s);
    _load();
  }

  Future<void> _export() async {
    if (_all.isEmpty) return;
    await CsvService.exportAndShare(_all, filterLabel: 'export');
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LEAD CARD — Premium Design
// ═══════════════════════════════════════════════════════════════════════════════

class _LeadCard extends StatelessWidget {
  final Prospect prospect;
  final VoidCallback onTap;
  final void Function(ProspectStatus) onStatusChanged;

  const _LeadCard({required this.prospect, required this.onTap, required this.onStatusChanged});

  static const _srcLabels = {
    'news': ('📰', 'Notizia'),
    'web': ('🔍', 'Web'),
    'scia': ('🏛️', 'SCIA'),
    'registro': ('📋', 'Registro'),
    'social': ('📱', 'Social'),
  };

  @override
  Widget build(BuildContext context) {
    final p = prospect;
    final color = Color(p.urgency.colorValue);
    final dist = LocationService.instance.formatDistance(p.distanceMeters);
    final src = _srcLabels[p.source] ?? ('📰', 'Fonte');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Row 1: Urgency + Name + Confidence ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Urgency circle
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(child: Text(p.urgency.emoji, style: const TextStyle(fontSize: 14))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.2),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Row(children: [
                          const Icon(Icons.location_on_outlined, size: 11, color: Colors.white24),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(p.address,
                              style: const TextStyle(color: Colors.white24, fontSize: 11),
                              maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Confidence pill
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _confCol(p.confidenceScore).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${p.confidenceScore}%',
                          style: TextStyle(color: _confCol(p.confidenceScore),
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 3),
                      Text(dist, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ── Row 2: Follow-up warning (if needed) ──
              if (p.needsFollowUp) ...[  
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.alarm, size: 12, color: Colors.orange),
                    const SizedBox(width: 4),
                    Text(
                      p.daysSinceLastContact < 0 ? 'Mai contattato' : 'Ultimo contatto ${p.daysSinceLastContact}g fa',
                      style: const TextStyle(color: Colors.orange, fontSize: 10)),
                  ]),
                ),
              ],

              // ── Row 3: Badges ──
              Row(
                children: [
                  // Source
                  _badge(src.$1, src.$2, Colors.white10, Colors.white30),
                  const SizedBox(width: 5),
                  // Verified
                  if (p.verified)
                    _badge('✅', 'Verificato', const Color(0xFF4CAF50).withOpacity(0.1), const Color(0xFF4CAF50)),
                  if (p.verified) const SizedBox(width: 5),
                  // Business type
                  if (p.businessType != null && p.businessType!.isNotEmpty)
                    Expanded(
                      child: Text(p.businessType!, style: const TextStyle(color: Colors.white24, fontSize: 10),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  // Status chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Color(p.status.colorValue).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(p.status.label,
                      style: TextStyle(color: Color(p.status.colorValue), fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),

              // ── Row 3: AI notes (if present) ──
              if (p.notes != null && p.notes!.startsWith('🤖')) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E7D32).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(p.notes!,
                    style: const TextStyle(color: Colors.white30, fontSize: 10, fontStyle: FontStyle.italic),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],

              // ── Row 4: Quick action ──
              if (p.status == ProspectStatus.nuovo || p.status == ProspectStatus.daVisitare ||
                  p.status == ProspectStatus.visitato) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (p.phone != null) ...[
                      const Icon(Icons.phone, size: 12, color: Colors.white24),
                      const SizedBox(width: 4),
                      Text(p.phone!, style: const TextStyle(fontSize: 10, color: Colors.white24)),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    _quickAction(p),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String emoji, String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 10)),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 9, color: fg)),
      ]),
    );
  }

  Widget _quickAction(Prospect p) {
    String label;
    Color color;
    ProspectStatus next;

    if (p.status == ProspectStatus.nuovo) {
      label = '→ Da visitare'; color = const Color(0xFFFF6F00); next = ProspectStatus.daVisitare;
    } else if (p.status == ProspectStatus.daVisitare) {
      label = '→ Visitato'; color = const Color(0xFF1565C0); next = ProspectStatus.visitato;
    } else {
      label = '→ Interessato!'; color = const Color(0xFF6A1B9A); next = ProspectStatus.interessato;
    }

    return GestureDetector(
      onTap: () => onStatusChanged(next),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Color _confCol(int s) => s >= 70 ? const Color(0xFF4CAF50)
      : s >= 40 ? const Color(0xFFF9A825) : const Color(0xFFEF5350);
}
