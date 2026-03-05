import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class UpdaterService {
  // L'URL del file JSON su GitHub
  static const String updateUrl = 'https://raw.githubusercontent.com/tony88pisa/crm-toscana/main/version.json';

  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final int currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await http.get(Uri.parse(updateUrl)).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final int latestBuild = data['versionCode'] ?? 0;

        // Se la versione su GitHub è maggiore, mostra il pop-up
        if (latestBuild > currentBuild) {
          if (context.mounted) {
            _showUpdateDialog(
              context,
              data['versionName'] ?? 'Nuova versione',
              data['updateMessage'] ?? 'Aggiornamento disponibile.',
              data['apkUrl'] ?? '',
            );
          }
        }
      }
    } catch (e) {
      // Ignoriamo gli errori in background (es. niente internet)
      debugPrint("Updater check failed: $e");
    }
  }

  static void _showUpdateDialog(BuildContext context, String version, String notes, String downloadUrl) {
    if (downloadUrl.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false, // L'utente DEVE scegliere
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C2333),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.system_update_alt, color: Color(0xFF4CAF50)),
            SizedBox(width: 8),
            Text('Nuovo Aggiornamento!', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versione disponibile: $version', style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text(notes, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                   Icon(Icons.info_outline, color: Colors.orange, size: 16),
                   SizedBox(width: 8),
                   Expanded(child: Text('Scaricando l\'aggiornamento non perderai i tuoi clienti.', style: TextStyle(color: Colors.orange, fontSize: 11))),
                ]),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Più tardi', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
              onPressed: () {
                Navigator.pop(ctx);
                _downloadAndInstall(context, downloadUrl);
              },
              child: const Text('Scarica & Aggiorna', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _downloadAndInstall(BuildContext context, String url) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _DownloadProgressDialog(),
    );

    try {
      final dir = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/app-update.apk';
      
      final dio = Dio();
      await dio.download(url, filePath);

      if (context.mounted) Navigator.pop(context); // Chiudi il pop-up di download

      // Avvia l'installazione APK
      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossibile aprire il file di installazione.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Chiudi dialog in caso di errore
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Errore durante il download dell\'aggiornamento')),
        );
      }
    }
  }
}

class _DownloadProgressDialog extends StatelessWidget {
  const _DownloadProgressDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C2333),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Color(0xFF4CAF50)),
            SizedBox(height: 20),
            Text('Scaricando Aggiornamento...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Non chiudere l\'applicazione', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
