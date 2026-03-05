// lib/screens/map_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:geolocator/geolocator.dart';
import '../database/database_helper.dart';
import '../models/prospect.dart';
import '../services/location_service.dart';
import 'prospect_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final MapController _mapController = MapController();
  List<Prospect> _prospects = [];
  bool _loading = true;
  String _filterProvince = 'Tutte';
  Position? _myPosition;

  static const LatLng _toscanCenter = LatLng(43.5, 11.0);
  static const List<String> _provinces = [
    'Tutte', 'Firenze', 'Siena', 'Arezzo', 'Pisa',
    'Livorno', 'Grosseto', 'Lucca', 'Massa-Carrara', 'Pistoia', 'Prato',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _myPosition = LocationService.instance.lastKnownPosition
        ?? await LocationService.instance.getCurrentPosition();
    final data = await DatabaseHelper.instance.getAllProspects(
      province: _filterProvince == 'Tutte' ? null : _filterProvince,
    );
    if (mounted) setState(() { _prospects = data; _loading = false; });
  }

  void _goToMyLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null) {
      _mapController.move(LatLng(pos.latitude, pos.longitude), 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Mappa – ${_prospects.length} prospect'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Aggiorna',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: _buildProvinceFilter(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                _buildMap(),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: _buildFabs(),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: _buildLegend(),
                ),
              ],
            ),
    );
  }

  Widget _buildProvinceFilter() {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        itemCount: _provinces.length,
        itemBuilder: (_, i) {
          final p = _provinces[i];
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text(p),
              selected: _filterProvince == p,
              onSelected: (_) {
                setState(() => _filterProvince = p);
                _load();
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMap() {
    final markers = <Marker>[];

    // Marker posizione utente
    if (_myPosition != null) {
      markers.add(Marker(
        point: LatLng(_myPosition!.latitude, _myPosition!.longitude),
        width: 40,
        height: 40,
        child: const _MyLocationMarker(),
      ));
    }

    // Marker prospect
    for (final p in _prospects) {
      markers.add(Marker(
        point: LatLng(p.lat, p.lng),
        width: 36,
        height: 36,
        child: GestureDetector(
          onTap: () => _openDetail(p),
          child: _ProspectPin(status: p.status),
        ),
      ));
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _myPosition != null
            ? LatLng(_myPosition!.latitude, _myPosition!.longitude)
            : _toscanCenter,
        initialZoom: _myPosition != null ? 12.0 : 8.0,
        maxZoom: 18.0,
        minZoom: 6.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'it.crm.toscana',
          maxZoom: 18,
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildFabs() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'zoom_toscana',
          onPressed: () => _mapController.move(_toscanCenter, 8.0),
          child: const Icon(Icons.zoom_out_map),
          tooltip: 'Panoramica Toscana',
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'my_location',
          onPressed: _goToMyLocation,
          child: const Icon(Icons.my_location),
          tooltip: 'La mia posizione',
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: ProspectStatus.values
            .where((s) => s != ProspectStatus.chiusoPerso)
            .map((s) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color(s.colorValue),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(s.label, style: const TextStyle(fontSize: 10)),
                  ],
                ))
            .toList(),
      ),
    );
  }

  void _openDetail(Prospect p) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProspectDetailScreen(prospect: p)),
    );
    _load(); // ricarica dopo modifica
  }
}

class _ProspectPin extends StatelessWidget {
  final ProspectStatus status;
  const _ProspectPin({required this.status});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PinPainter(Color(status.colorValue)),
    );
  }
}

class _PinPainter extends CustomPainter {
  final Color color;
  _PinPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cx = size.width / 2;
    final r = size.width * 0.38;
    // Testa del pin
    canvas.drawCircle(Offset(cx, r), r, paint);
    canvas.drawCircle(Offset(cx, r), r, borderPaint);
    // Coda del pin
    final path = Path()
      ..moveTo(cx - r * 0.5, r * 1.5)
      ..lineTo(cx, size.height)
      ..lineTo(cx + r * 0.5, r * 1.5)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinPainter old) => old.color != color;
}

class _MyLocationMarker extends StatelessWidget {
  const _MyLocationMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 8, spreadRadius: 4)],
      ),
    );
  }
}
