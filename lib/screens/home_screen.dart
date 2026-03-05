// lib/screens/home_screen.dart — v6

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../services/location_service.dart';
import 'map_screen.dart';
import 'list_screen.dart';
import 'search_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  Map<String, int> _stats = {};
  int _total = 0;
  bool _geofencingActive = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final granted = await LocationService.instance.requestPermissions();
    if (granted) {
      await LocationService.instance.getCurrentPosition();
      LocationService.instance.startGeofencing();
      if (mounted) setState(() => _geofencingActive = true);
    }
  }

  Future<void> _loadStats() async {
    final stats = await DatabaseHelper.instance.getStatsByStatus();
    final total = await DatabaseHelper.instance.getTotalCount();
    if (mounted) setState(() { _stats = stats; _total = total; });
  }

  @override
  void dispose() {
    LocationService.instance.stopGeofencing();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onRefresh: _loadStats),
      ListScreen(onRefresh: _loadStats),
      SearchScreen(onNewProspects: _loadStats),
      const MapScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        height: 64,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: (_stats['nuovo'] ?? 0) > 0,
              label: Text('${_stats['nuovo'] ?? 0}'),
              child: const Icon(Icons.list_alt_outlined),
            ),
            selectedIcon: const Icon(Icons.list_alt),
            label: 'Lead',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Cerca',
          ),
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mappa',
          ),
        ],
      ),
    );
  }
}
