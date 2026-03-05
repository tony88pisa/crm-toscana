// lib/services/location_service.dart

import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/prospect.dart';
import '../database/database_helper.dart';

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  DateTime? _lastNotificationTime;

  // Raggio geofence in metri
  static const double kGeofenceRadius = 400.0;
  // Minimo minuti tra notifiche per evitare spam
  static const int kNotificationCooldownMinutes = 5;

  // ─── INIT ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _notifications.initialize(initSettings);

    // Crea canale notifiche Android 8+
    const channel = AndroidNotificationChannel(
      'prospect_alerts',
      'Allerte Prospect',
      description: 'Notifiche quando sei vicino a un prospect da visitare',
      importance: Importance.high,
      playSound: true,
    );
    final androidPlugin =
        _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }

  // ─── PERMESSI ──────────────────────────────────────────────────────────────

  Future<bool> requestPermissions() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  // ─── POSIZIONE ATTUALE ─────────────────────────────────────────────────────

  Future<Position?> getCurrentPosition() async {
    final hasPermission = await requestPermissions();
    if (!hasPermission) return null;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _lastPosition = pos;
      return pos;
    } catch (_) {
      return _lastPosition;
    }
  }

  Position? get lastKnownPosition => _lastPosition;

  // ─── DISTANZA ─────────────────────────────────────────────────────────────

  double? distanceTo(double lat, double lng) {
    if (_lastPosition == null) return null;
    return Geolocator.distanceBetween(
      _lastPosition!.latitude,
      _lastPosition!.longitude,
      lat,
      lng,
    );
  }

  static double distanceBetween(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(a.latitude, a.longitude, b.latitude, b.longitude);
  }

  // ─── GEOFENCING ───────────────────────────────────────────────────────────

  void startGeofencing() {
    _positionSub?.cancel();

    const settings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 100, // aggiorna ogni 100m percorsi
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPositionUpdate);
  }

  void stopGeofencing() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  Future<void> _onPositionUpdate(Position position) async {
    _lastPosition = position;

    // Anti-spam: non notificare più spesso del cooldown
    if (_lastNotificationTime != null) {
      final diff = DateTime.now().difference(_lastNotificationTime!).inMinutes;
      if (diff < kNotificationCooldownMinutes) return;
    }

    // Carica i prospect non ancora visitati
    final unvisited = await DatabaseHelper.instance.getUnvisitedProspects();

    // Controlla se siamo vicini ad almeno uno
    final nearby = unvisited.where((p) {
      final dist = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        p.lat,
        p.lng,
      );
      return dist <= kGeofenceRadius;
    }).toList();

    if (nearby.isNotEmpty) {
      _lastNotificationTime = DateTime.now();
      await _sendProximityNotification(nearby);
    }
  }

  Future<void> _sendProximityNotification(List<Prospect> nearby) async {
    final count = nearby.length;
    final title = count == 1
        ? '📍 Prospect vicino: ${nearby.first.name}'
        : '📍 $count prospect nelle vicinanze!';

    final body = count == 1
        ? 'A ${kGeofenceRadius.toInt()}m da te – ${nearby.first.address}'
        : nearby.map((p) => p.name).take(3).join(', ') +
            (count > 3 ? ' e altri...' : '');

    const androidDetails = AndroidNotificationDetails(
      'prospect_alerts',
      'Allerte Prospect',
      channelDescription: 'Prospect vicini da visitare',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    await _notifications.show(
      1,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  // ─── SORT PER DISTANZA ────────────────────────────────────────────────────

  List<Prospect> sortByDistance(List<Prospect> prospects) {
    if (_lastPosition == null) return prospects;

    for (final p in prospects) {
      p.distanceMeters = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        p.lat,
        p.lng,
      );
    }

    return prospects..sort((a, b) {
      final da = a.distanceMeters ?? double.infinity;
      final db = b.distanceMeters ?? double.infinity;
      return da.compareTo(db);
    });
  }

  String formatDistance(double? meters) {
    if (meters == null) return '–';
    if (meters < 1000) return '${meters.toInt()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
