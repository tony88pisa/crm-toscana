// lib/screens/search_screen.dart

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/maps_service.dart';
import '../models/prospect.dart';

import '../services/storage_service.dart';
import '../services/ai_service.dart';
import 'settings_screen.dart';

class SearchScreen extends StatefulWidget {
  final VoidCallback? onNewProspects;
  const SearchScreen({super.key, this.onNewProspects});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  String _selectedProvince = 'Firenze';
  String _selectedType = 'Ristoranti & Bar';
  bool _loading = false;
  String? _errorMsg;
  int _newAdded = 0;
  int _totalFetched = 0;
  int _verified = 0;
  int _apiRemaining = 0;

  // Progress state
  int _currentStep = 0;
  String _stepName = '';
  String _stepDetail = '';

  final List<String> _provinces = kProvince.keys.toList();
  final List<String> _types = kBusinessTypes.keys.toList();

  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _loadApiUsage();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadApiUsage() async {
    final remaining = await MapsService.getApiRemaining();
    if (mounted) setState(() => _apiRemaining = remaining);
  }

  Future<void> _startSearch() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
      _newAdded = 0;
      _totalFetched = 0;
      _verified = 0;
      _currentStep = 0;
    });

    try {
      final prospects = await MapsService.searchBusinesses(
        province: _selectedProvince,
        businessTypeKey: _selectedType,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _currentStep = progress.step;
              _stepName = progress.stepName;
              _stepDetail = progress.detail;
              _totalFetched = progress.found;
              _verified = progress.verified;
            });
          }
        },
      );

      setState(() {
        _totalFetched = prospects.length;
        _stepDetail = 'Salvataggio in corso…';
      });

      final inserted = await DatabaseHelper.instance.insertProspects(prospects);
      await _loadApiUsage();

      setState(() {
        _newAdded = inserted;
        _loading = false;
      });

      widget.onNewProspects?.call();
    } catch (e) {
      if (e is UserApiKeyMissingException) {
        _showKeyMissingDialog();
      } else {
        setState(() {
          _errorMsg = e.toString().replaceFirst('Exception: ', '');
          _loading = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showKeyMissingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        title: const Text('API Key Mancante'),
        content: const Text(
          'Per analizzare i lead con l\'AI, ogni collega deve inserire la propria Gemini API Key gratuita nelle impostazioni.\n\nVuoi andare alle impostazioni ora?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen())).then((_) => setState(() {}));
            },
            child: const Text('Vai alle Impostazioni'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔍 Nuove Aperture'),
        actions: [
          _buildGeminiBadge(),
          const SizedBox(width: 8),
          _buildApiBadge(),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 20),
            _buildSelector(
              label: '📍 Provincia',
              value: _selectedProvince,
              items: _provinces,
              onChanged: (v) => setState(() => _selectedProvince = v!),
            ),
            const SizedBox(height: 14),
            _buildSelector(
              label: '🏪 Tipo di attività',
              value: _selectedType,
              items: _types,
              onChanged: (v) => setState(() => _selectedType = v!),
            ),
            const SizedBox(height: 24),
            _buildSearchButton(),
            const SizedBox(height: 20),
            if (_loading) _buildPipelineProgress(),
            if (_errorMsg != null) _buildError(),
            if (!_loading && _newAdded > 0) _buildSuccess(),
            if (!_loading && _totalFetched > 0 && _newAdded == 0) _buildNoNew(),
          ],
        ),
      ),
    );
  }

  Widget _buildApiBadge() {
    final pct = (_apiRemaining / kMonthlyApiLimit * 100).round();
    final color = pct > 50
        ? const Color(0xFF4CAF50)
        : pct > 20
            ? const Color(0xFFF9A825)
            : const Color(0xFFC62828);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$_apiRemaining',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildGeminiBadge() {
    final stats = StorageService.getQuotaStats();
    final tokens = stats['tokens'] ?? 0;
    const color = Colors.amber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.token, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '${(tokens/1000).toStringAsFixed(1)}k',
            style: const TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.rocket_launch, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text('Ricerca Intelligente',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          _pipelineRow('📰', '5 Fonti', 'News · Web · SCIA · Registro · Social'),
          _pipelineRow('✅', 'Verifica', 'Conferma su Google Places'),
          _pipelineRow('🤖', 'AI', 'Gemini valida ogni risultato'),
          _pipelineRow('🎯', 'Urgenza', 'Classifica per opportunità'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🟢', style: TextStyle(fontSize: 12)),
                SizedBox(width: 4),
                Text('+1 mese', style: TextStyle(color: Colors.white70, fontSize: 11)),
                SizedBox(width: 10),
                Text('🟡', style: TextStyle(fontSize: 12)),
                SizedBox(width: 4),
                Text('1-2 sett.', style: TextStyle(color: Colors.white70, fontSize: 11)),
                SizedBox(width: 10),
                Text('🔴', style: TextStyle(fontSize: 12)),
                SizedBox(width: 4),
                Text('<1 sett.', style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pipelineRow(String emoji, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text('— $desc', style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSelector({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: const Color(0xFF1C2333),
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
          onChanged: _loading ? null : onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _loading ? null : _startSearch,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          disabledBackgroundColor: const Color(0xFF1B5E20).withOpacity(0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _loading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Text(_stepName.isEmpty ? 'Avvio…' : _stepName,
                      style: const TextStyle(fontSize: 15)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radar, size: 20),
                  SizedBox(width: 8),
                  Text('Avvia ricerca precisa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }

  Widget _buildPipelineProgress() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2333),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicators
          Row(
            children: [
              _stepDot(1, '📰', _currentStep >= 1),
              _stepLine(_currentStep >= 2),
              _stepDot(2, '✅', _currentStep >= 2),
              _stepLine(_currentStep >= 3),
              _stepDot(3, '🤖', _currentStep >= 3),
              _stepLine(_currentStep >= 4),
              _stepDot(4, '🎯', _currentStep >= 4),
            ],
          ),
          const SizedBox(height: 12),
          // Current step name
          Text(_stepName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          // Detail
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (context, child) {
              return Opacity(
                opacity: 0.6 + (_pulseCtrl.value) * 0.4,
                child: Text(_stepDetail,
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              );
            },
          ),
          const SizedBox(height: 10),
          // Stats
          Row(
            children: [
              _miniStat('Trovati', _totalFetched, const Color(0xFF42A5F5)),
              const SizedBox(width: 16),
              _miniStat('Verificati', _verified, const Color(0xFF4CAF50)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepDot(int step, String emoji, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF2E7D32).withOpacity(0.3)
            : Colors.white.withOpacity(0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? const Color(0xFF4CAF50) : Colors.white12,
          width: _currentStep == step ? 2 : 1,
        ),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 14))),
    );
  }

  Widget _stepLine(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: active ? const Color(0xFF4CAF50).withOpacity(0.5) : Colors.white10,
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text('$label: ', style: const TextStyle(color: Colors.white38, fontSize: 11)),
        Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFC62828).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFC62828).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.error_outline, color: Color(0xFFC62828), size: 18),
            SizedBox(width: 8),
            Text('Errore', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFEF5350))),
          ]),
          const SizedBox(height: 6),
          Text(_errorMsg!, style: const TextStyle(fontSize: 12, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2E7D32).withOpacity(0.15), const Color(0xFF1B5E20).withOpacity(0.08)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 44),
          const SizedBox(height: 10),
          Text(
            '$_newAdded nuove aperture trovate!',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 4),
          Text(
            '$_totalFetched notizie analizzate · $_verified verificate su Google',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 12),
          const Text(
            '🟢 = Opportunità calda (apre tra 1+ mese)\n'
            '🟡 = Si sta decidendo (1-2 settimane)\n'
            '🔴 = Forse tardi (<1 settimana)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildNoNew() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9A825).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF9A825).withOpacity(0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF9A825), size: 36),
          const SizedBox(height: 8),
          Text(
            'Trovate $_totalFetched notizie, tutte già in archivio.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFFF9A825)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Riprova tra qualche giorno o cambia filtri.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
