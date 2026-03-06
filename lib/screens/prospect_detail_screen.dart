// lib/screens/prospect_detail_screen.dart — v6

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../database/database_helper.dart';
import '../models/prospect.dart';

class ProspectDetailScreen extends StatefulWidget {
  final Prospect prospect;
  const ProspectDetailScreen({super.key, required this.prospect});

  @override
  State<ProspectDetailScreen> createState() => _ProspectDetailScreenState();
}

class _ProspectDetailScreenState extends State<ProspectDetailScreen> {
  late Prospect p;
  List<ContactLog> _logs = [];
  bool _loadingLogs = true;

  @override
  void initState() {
    super.initState();
    p = widget.prospect;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    if (p.id == null) { setState(() => _loadingLogs = false); return; }
    final logs = await DatabaseHelper.instance.getContactLogs(p.id!);
    if (mounted) setState(() { _logs = logs; _loadingLogs = false; });
  }

  @override
  Widget build(BuildContext context) {
    final urgColor = Color(p.urgency.colorValue);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio Lead'),
        actions: [
          IconButton(icon: const Icon(Icons.block, size: 20, color: Colors.redAccent),
            onPressed: _reportFalsePositive, tooltip: 'Falso Positivo / Blacklist'),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: _delete, tooltip: 'Elimina'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ── HEADER ──
          _header(urgColor),
          const SizedBox(height: 10),

          // ── URGENZA ──
          Row(children: [
            Expanded(child: _infoCard(p.urgency.emoji, p.urgency.label, urgColor)),
            const SizedBox(width: 8),
            Expanded(child: _infoCard('🎯', '${p.confidenceScore}% affidabilità',
              p.confidenceScore >= 70 ? const Color(0xFF4CAF50)
                  : p.confidenceScore >= 40 ? const Color(0xFFF9A825) : const Color(0xFFEF5350))),
          ]),
          const SizedBox(height: 8),

          // ── SOURCE E CONTATTI EXTRA ──
          Row(children: [
            Expanded(child: _infoCard(_sourceEmoji, _sourceLabel, Colors.white38)),
            if (p.ownerName != null || p.extractedPhone != null || p.email != null) ...[
              const SizedBox(width: 8),
              Expanded(child: _infoCard('👤', 'Contatti trovati', const Color(0xFF42A5F5))),
            ]
          ]),
          const SizedBox(height: 12),

          // ── AZIONI RAPIDE ──
          _buildQuickActions(),
          const SizedBox(height: 12),

          // ── STATUS ──
          _buildStatusSelector(),
          const SizedBox(height: 12),

          // ── TAGS ──
          _buildTags(),
          const SizedBox(height: 12),

          // ── NOTE AI ──
          if (p.notes != null && p.notes!.isNotEmpty)
            _sectionCard('🤖 Nota AI', p.notes!),
          if (p.notes != null && p.notes!.isNotEmpty) const SizedBox(height: 12),

          // ── LOG CONTATTI ──
          _buildContactLog(),
          const SizedBox(height: 12),

          // ── INFORMAZIONI ──
          _buildInfoSection(),
          const SizedBox(height: 20),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addContactEntry,
        backgroundColor: const Color(0xFF2E7D32),
        icon: const Icon(Icons.add),
        label: const Text('Log contatto'),
      ),
    );
  }

  // ── HEADER ──

  Widget _header(Color urgColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          urgColor.withOpacity(0.15), const Color(0xFF161B22),
        ], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: urgColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: urgColor.withOpacity(0.2), shape: BoxShape.circle),
              child: Center(child: Text(p.urgency.emoji, style: const TextStyle(fontSize: 20))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (p.businessType != null)
                  Text(p.businessType!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              ]),
            ),
            if (p.verified) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified, size: 14, color: Color(0xFF4CAF50)),
                SizedBox(width: 4),
                Text('Verificato', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.location_on_outlined, size: 14, color: Colors.white30),
            const SizedBox(width: 4),
            Expanded(child: Text(p.address, style: const TextStyle(color: Colors.white30, fontSize: 12))),
          ]),
          if (p.phone != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.phone_outlined, size: 14, color: Colors.white30),
              const SizedBox(width: 4),
              Text(p.phone!, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ]),
          ],
          if (p.needsFollowUp) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.alarm, size: 14, color: Colors.orange),
                const SizedBox(width: 4),
                Text(
                  p.daysSinceLastContact < 0
                      ? 'Mai contattato!'
                      : 'Ultimo contatto ${p.daysSinceLastContact} giorni fa',
                  style: const TextStyle(color: Colors.orange, fontSize: 11)),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoCard(String emoji, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 6),
        Expanded(child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  // ── AZIONI RAPIDE ──

  Widget _buildQuickActions() {
    return Row(children: [
      _actionBtn('📞', 'Chiama', () => _callPhone()),
      const SizedBox(width: 6),
      _actionBtn('💬', 'WhatsApp', () => _shareWhatsApp()),
      const SizedBox(width: 6),
      _actionBtn('🗺️', 'Mappa', () => _openMaps()),
      const SizedBox(width: 6),
      if (p.sourceUrl != null)
        _actionBtn('🔗', 'Fonte', () => _openUrl(p.sourceUrl!)),
    ]);
  }

  Widget _actionBtn(String emoji, String label, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1C2333),
            borderRadius: BorderRadius.circular(10)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.white38)),
          ]),
        ),
      ),
    );
  }

  // ── STATUS SELECTOR ──

  Widget _buildStatusSelector() {
    return _sectionContainer('Stato', Wrap(
      spacing: 6, runSpacing: 6,
      children: ProspectStatus.values.map((s) {
        final selected = p.status == s;
        final color = Color(s.colorValue);
        return GestureDetector(
          onTap: () async {
            await DatabaseHelper.instance.updateStatus(p.id!, s);
            setState(() => p.status = s);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? color : Colors.white10)),
            child: Text(s.label, style: TextStyle(
              color: selected ? color : Colors.white30,
              fontSize: 11, fontWeight: selected ? FontWeight.w600 : FontWeight.normal)),
          ),
        );
      }).toList(),
    ));
  }

  // ── TAGS ──

  Widget _buildTags() {
    final tags = p.tagList;
    final presets = ['Registratore cercato', 'POS touch', 'Fiscalizzazione',
        'Già ha fornitore', 'Preventivo fatto', 'Da richiamare', 'Budget basso', 'Urgente'];

    return _sectionContainer('🏷️ Tag', Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tags.isNotEmpty) Wrap(
          spacing: 4, runSpacing: 4,
          children: tags.map((t) => Chip(
            label: Text(t, style: const TextStyle(fontSize: 10)),
            deleteIcon: const Icon(Icons.close, size: 14),
            onDeleted: () => _removeTag(t),
            backgroundColor: const Color(0xFF2E7D32).withOpacity(0.15),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          )).toList(),
        ),
        if (tags.isNotEmpty) const SizedBox(height: 6),
        Wrap(
          spacing: 4, runSpacing: 4,
          children: presets.where((t) => !tags.contains(t)).map((t) =>
            GestureDetector(
              onTap: () => _addTag(t),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white10),
                  borderRadius: BorderRadius.circular(15)),
                child: Text('+ $t', style: const TextStyle(color: Colors.white24, fontSize: 10)),
              ),
            ),
          ).toList(),
        ),
      ],
    ));
  }

  // ── CONTACT LOG ──

  Widget _buildContactLog() {
    return _sectionContainer('📞 Registro contatti', Column(
      children: [
        if (_loadingLogs)
          const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(strokeWidth: 2))
        else if (_logs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Nessun contatto registrato.\nPremi + per aggiungerne uno.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white24, fontSize: 12)))
        else
          ..._logs.take(10).map((log) => Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.typeEmoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text(log.typeLabel, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                        const Spacer(),
                        Text(_formatDate(log.createdAt),
                          style: const TextStyle(color: Colors.white24, fontSize: 10)),
                      ]),
                      if (log.notes != null && log.notes!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(log.notes!, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                      if (log.outcome != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          log.outcome == 'positive' ? '✅ Positivo'
                              : log.outcome == 'negative' ? '❌ Negativo'
                              : '⚪ Neutro',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          )),
      ],
    ));
  }

  // ── INFO SECTION ──

  Widget _buildInfoSection() {
    return _sectionContainer('📋 Informazioni', Column(
      children: [
        _infoRow('Provincia', p.province),
        _infoRow('Creato', _formatDate(p.createdAt)),
        if (p.lastContactAt != null) _infoRow('Ultimo contatto', _formatDate(p.lastContactAt!)),
        if (p.estimatedOpenDate != null) _infoRow('Apertura stimata', _formatDate(p.estimatedOpenDate!)),
        _infoRow('ID Google', p.googlePlaceId ?? 'N/A'),
        const SizedBox(height: 16),
            _buildSectionTitle('Dati AI & Contatti (Beta)', Icons.auto_awesome),
            const SizedBox(height: 8),

            // NOME TITOLARE / REFERENTE
            if (p.ownerName != null && p.ownerName!.isNotEmpty)
              _infoCard('👤', 'Referente: ${p.ownerName!}', Colors.purple)
            else
              _buildMissingContactRow(
                context,
                title: 'Titolare non trovato',
                icon: Icons.person_search,
                searchQuery: '"${p.name}" "${p.address}" (titolare OR proprietario OR gestore)',
              ),
            
            // NUMERO DI TELEFONO PROBABILE
            if (p.extractedPhone != null && p.extractedPhone!.isNotEmpty)
              _infoCard('📞', 'Tel. Estratto: ${p.extractedPhone!}', Colors.blue)
            else
              _buildMissingContactRow(
                context,
                title: 'Telefono non trovato',
                icon: Icons.phone_android,
                searchQuery: '"${p.name}" "${p.address}" telefono',
              ),

            // EMAIL
            if (p.email != null && p.email!.isNotEmpty)
              _infoCard('✉️', 'Email: ${p.email!}', Colors.orange),
      ],
    ));
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.white24, fontSize: 11))),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _buildMissingContactRow(BuildContext context, {required String title, required IconData icon, required String searchQuery}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 13, fontStyle: FontStyle.italic))),
          TextButton.icon(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.05),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => _launchGoogleSearch(searchQuery),
            icon: const Icon(Icons.search, size: 16, color: Colors.blueAccent),
            label: const Text('Cerca', style: TextStyle(color: Colors.blueAccent, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchGoogleSearch(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = Uri.parse('https://www.google.com/search?q=$encodedQuery');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── SECTION CONTAINER ──

  Widget _sectionContainer(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _sectionCard(String title, String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // ── ACTIONS ──

  void _callPhone() {
    if (p.phone != null) launchUrl(Uri.parse('tel:${p.phone}'));
  }

  void _shareWhatsApp() {
    final text = '🏪 *${p.name}*\n📍 ${p.address}\n'
        '${p.phone != null ? '📞 ${p.phone}\n' : ''}'
        '${p.extractedPhone != null ? '📱 Cellulare estr.: ${p.extractedPhone}\n' : ''}'
        '${p.ownerName != null ? '👤 Titolare: ${p.ownerName}\n' : ''}'
        '${p.urgency.emoji} ${p.urgency.label}\n\n'
        'Trovato con CRM Toscana di Sistemi Digitali Group';
    final encoded = Uri.encodeComponent(text);
    launchUrl(Uri.parse('https://wa.me/?text=$encoded'));
  }

  void _openMaps() {
    final query = Uri.encodeComponent('${p.name} ${p.address} ${p.province}');
    String url = 'https://www.google.com/maps/search/?api=1&query=$query';
    if (p.googlePlaceId != null) {
      url += '&query_place_id=${p.googlePlaceId}';
    }
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _addTag(String tag) async {
    final newTags = [...p.tagList, tag].join(',');
    await DatabaseHelper.instance.updateTags(p.id!, newTags);
    setState(() => p = p.copyWith(tags: newTags));
  }

  void _removeTag(String tag) async {
    final newTags = p.tagList.where((t) => t != tag).join(',');
    await DatabaseHelper.instance.updateTags(p.id!, newTags);
    setState(() => p = p.copyWith(tags: newTags));
  }

  Future<void> _addContactEntry() async {
    String? selectedType;
    String? notes;
    String? outcome;

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: const Color(0xFF1C2333),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Registra contatto', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                // Type
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final t in ['call', 'visit', 'whatsapp', 'email', 'note'])
                    GestureDetector(
                      onTap: () => setModalState(() => selectedType = t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selectedType == t ? const Color(0xFF2E7D32).withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selectedType == t ? const Color(0xFF4CAF50) : Colors.white10)),
                        child: Text(
                          t == 'call' ? '📞 Chiamata' : t == 'visit' ? '🏠 Visita'
                              : t == 'whatsapp' ? '💬 WhatsApp' : t == 'email' ? '📧 Email' : '📝 Nota',
                          style: TextStyle(fontSize: 12, color: selectedType == t ? const Color(0xFF4CAF50) : Colors.white38)),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                // Notes
                TextField(
                  onChanged: (v) => notes = v,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Note (opzionale)…',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(12)),
                ),
                const SizedBox(height: 8),
                // Outcome
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final o in [('positive', '✅'), ('neutral', '⚪'), ('negative', '❌')])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => setModalState(() => outcome = o.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: outcome == o.$1 ? Colors.white.withOpacity(0.08) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: outcome == o.$1 ? Colors.white24 : Colors.white10)),
                          child: Text(o.$2, style: const TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                ]),
                const SizedBox(height: 12),
                // Save
                SizedBox(
                  width: double.infinity, height: 44,
                  child: ElevatedButton(
                    onPressed: selectedType != null
                        ? () => Navigator.pop(ctx, {'type': selectedType!, 'notes': notes ?? '', 'outcome': outcome ?? ''})
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: const Text('Salva', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );

    if (result != null && p.id != null) {
      await DatabaseHelper.instance.addContactLog(ContactLog(
        prospectId: p.id!,
        type: result['type']!,
        notes: result['notes']!.isEmpty ? null : result['notes'],
        createdAt: DateTime.now(),
        outcome: result['outcome']!.isEmpty ? null : result['outcome'],
      ));
      await _loadLogs();
      // Refresh prospect
      final updated = await DatabaseHelper.instance.getProspectById(p.id!);
      if (updated != null && mounted) setState(() => p = updated);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('Elimina lead?', style: TextStyle(fontSize: 16)),
        content: Text('Eliminare "${p.name}" e tutto il suo storico?',
          style: const TextStyle(color: Colors.white60, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Elimina')),
        ],
      ));
    if (confirm == true && p.id != null) {
      await DatabaseHelper.instance.deleteProspect(p.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _reportFalsePositive() async {
    final confirm = await showDialog<bool>(context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('Segnala Falso Positivo?', style: TextStyle(fontSize: 16)),
        content: const Text(
          'Questo lead verrà eliminato e inserito in BLACKLIST.\nNon comparirà mai più nelle future ricerche.',
          style: TextStyle(color: Colors.white60, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annulla')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Blacklist')),
        ],
      ));
    if (confirm == true && p.id != null) {
      await DatabaseHelper.instance.addToBlacklist(p.name, p.province);
      await DatabaseHelper.instance.deleteProspect(p.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lead inserito in Blacklist!', style: TextStyle(color: Colors.white)))
        );
        Navigator.pop(context);
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String get _sourceEmoji => const {'news': '📰', 'web': '🔍', 'scia': '🏛️', 'registro': '📋', 'social': '📱', 'hiring': '🎯'}[p.source] ?? '📰';
  String get _sourceLabel => const {'news': 'Notizia', 'web': 'Web', 'scia': 'SCIA', 'registro': 'Registro', 'social': 'Social', 'hiring': 'Assunzioni'}[p.source] ?? 'Fonte';
}
