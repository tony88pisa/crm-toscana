import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class UpdaterService {
  static const String _versionUrl =
      'https://raw.githubusercontent.com/tony88pisa/crm-toscana/main/version.json';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ═══════════════════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(initSettings);
  }

  static Future<void> triggerPushNotification(String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'updates_channel',
      'Aggiornamenti App',
      channelDescription: 'Notifiche per nuovi aggiornamenti del CRM',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF4CAF50),
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(999, title, body, notificationDetails);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FETCH UPDATE DATA (Silent)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>?> fetchLatestUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;
      final urlWithTimestamp = '$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      final resp = await http.get(
        Uri.parse(urlWithTimestamp),
        headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
      ).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return null;

      final data = jsonDecode(resp.body);
      final latestBuild = data['versionCode'] ?? 0;

      if (latestBuild > currentBuild) {
        return data;
      }
    } catch (e) {
      debugPrint('Silent update check failed: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHECK FOR UPDATES (Auto-Dialog)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> checkForUpdates(BuildContext context) async {
    final update = await fetchLatestUpdate();
    if (update != null && context.mounted) {
      showUpdateDialog(context, update);
    }
  }

  static void showUpdateDialog(BuildContext context, Map<String, dynamic> data) {
    _showUpdateDialog(
      context,
      data['versionName']?.toString() ?? '',
      data['updateMessage']?.toString() ?? 'Aggiornamento disponibile.',
      data['apkUrl']?.toString() ?? '',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UPDATE DIALOG
  // ═══════════════════════════════════════════════════════════════════════════

  static void _showUpdateDialog(
      BuildContext context, String version, String notes, String url) {
    if (url.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.system_update_alt, color: Color(0xFF4CAF50)),
          SizedBox(width: 8),
          Text('Nuovo Aggiornamento!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versione: $version',
                style: const TextStyle(
                    color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(notes,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 16),
                SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'I tuoi dati non verranno persi.',
                        style:
                            TextStyle(color: Colors.orange, fontSize: 11))),
              ]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dopo',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50)),
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndInstall(context, url);
            },
            child: const Text('Aggiorna',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DOWNLOAD & INSTALL  (rock-solid)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> _downloadAndInstall(
      BuildContext context, String url) async {
    final progress = ValueNotifier<double>(0);
    final statusText = ValueNotifier<String>('Preparazione...');
    bool dialogOpen = true;

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ProgressDialog(progress: progress, status: statusText),
    ).then((_) => dialogOpen = false);

    void closeDialog() {
      if (dialogOpen && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        dialogOpen = false;
      }
    }

    try {
      // ── Step 1: Determine save path ──────────────────────────────────
      statusText.value = 'Accesso storage...';
      final dir = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/crm_update.apk';
      final file = File(filePath);
      if (await file.exists()) await file.delete();

      // ── Step 2: Download with auto-redirect ─────────────────────────
      statusText.value = 'Connessione al server...';

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 15)
        ..badCertificateCallback = (_, __, ___) => true;

      final request = await client.getUrl(Uri.parse(url.trim()));
      // Let HttpClient follow redirects automatically (default behavior)
      request.followRedirects = true;
      request.maxRedirects = 10;

      final response = await request.close();

      if (response.statusCode != 200) {
        closeDialog();
        _showError(context,
            'Server ha risposto con codice ${response.statusCode}');
        client.close(force: true);
        return;
      }

      // ── Step 3: Stream to file with progress ────────────────────────
      statusText.value = 'Scaricando...';
      final totalBytes = response.contentLength;
      int received = 0;
      final sink = file.openWrite();

      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (totalBytes > 0) {
          progress.value = received / totalBytes;
          statusText.value =
              '${(received / 1048576).toStringAsFixed(1)} / ${(totalBytes / 1048576).toStringAsFixed(1)} MB';
        } else {
          statusText.value =
              '${(received / 1048576).toStringAsFixed(1)} MB scaricati';
        }
      }

      await sink.flush();
      await sink.close();
      client.close(force: true);

      // ── Step 4: Validate downloaded file ────────────────────────────
      final downloadedSize = await file.length();
      if (downloadedSize < 1000000) {
        // APK should be at least 1 MB
        closeDialog();
        _showError(context,
            'File scaricato troppo piccolo ($downloadedSize bytes). Riprova.');
        return;
      }

      // Verify APK magic bytes (PK\x03\x04)
      final header = await file.openRead(0, 4).first;
      if (header.length < 4 ||
          header[0] != 0x50 ||
          header[1] != 0x4B ||
          header[2] != 0x03 ||
          header[3] != 0x04) {
        closeDialog();
        _showError(context,
            'Il file scaricato non e\' un APK valido. Riprova.');
        await file.delete();
        return;
      }

      debugPrint('OTA: Download OK - $downloadedSize bytes - $filePath');

      // ── Step 5: Close dialog and launch installer ───────────────────
      closeDialog();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Download completato! Avvio installazione...'),
          backgroundColor: Color(0xFF4CAF50),
          duration: Duration(seconds: 2),
        ));
      }

      await Future.delayed(const Duration(milliseconds: 800));

      // Try open_filex first
      final result = await OpenFilex.open(
          filePath, type: 'application/vnd.android.package-archive');
      debugPrint('OTA: OpenFilex -> ${result.type} ${result.message}');

      if (result.type != ResultType.done && context.mounted) {
        // Fallback: try without MIME type
        final result2 = await OpenFilex.open(filePath);
        debugPrint('OTA: OpenFilex fallback -> ${result2.type} ${result2.message}');
        if (result2.type != ResultType.done && context.mounted) {
          _showError(context,
              'Non riesco ad aprire l\'installer. '
              'Apri il file manager e installa manualmente da:\n$filePath');
        }
      }
    } catch (e, stack) {
      debugPrint('OTA Error: $e\n$stack');
      closeDialog();
      _showError(context, 'Errore: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ERROR DISPLAY
  // ═══════════════════════════════════════════════════════════════════════════

  static void _showError(BuildContext context, String msg) {
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.error_outline, color: Colors.redAccent),
          SizedBox(width: 8),
          Text('Errore Aggiornamento',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ]),
        content: Text(msg,
            style: const TextStyle(color: Colors.white70, fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('OK', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROGRESS DIALOG WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _ProgressDialog extends StatelessWidget {
  final ValueNotifier<double> progress;
  final ValueNotifier<String> status;
  const _ProgressDialog({required this.progress, required this.status});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: const Color(0xFF1C2333),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (_, val, __) => Column(children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: Stack(alignment: Alignment.center, children: [
                      CircularProgressIndicator(
                        value: val > 0 ? val : null,
                        color: const Color(0xFF4CAF50),
                        strokeWidth: 6,
                      ),
                      if (val > 0)
                        Text('${(val * 100).toInt()}%',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: val > 0 ? val : null,
                      backgroundColor: Colors.white10,
                      color: const Color(0xFF4CAF50),
                      minHeight: 6,
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Scaricando Aggiornamento',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (_, val, __) => Text(val,
                    style: const TextStyle(
                        color: Color(0xFF4CAF50), fontSize: 13)),
              ),
              const SizedBox(height: 8),
              const Text('Non chiudere l\'app',
                  style: TextStyle(color: Colors.white24, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}
