// lib/services/csv_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/prospect.dart';

class CsvService {
  static const String _separator = ';';

  static Future<void> exportAndShare(
    List<Prospect> prospects, {
    String? filterLabel,
  }) async {
    final csv = _buildCsv(prospects);
    final file = await _writeFile(csv);
    await _share(file, prospects.length, filterLabel);
  }

  static String _buildCsv(List<Prospect> prospects) {
    final buf = StringBuffer();

    // BOM UTF-8 per Excel italiano
    buf.write('\uFEFF');

    // Intestazioni
    buf.writeln([
      'Nome',
      'Indirizzo',
      'Provincia',
      'Telefono',
      'Sito Web',
      'Stato',
      'Note',
      'Data aggiunta',
      'Ultimo contatto',
      'Tipo attività',
      'Distanza (km)',
    ].join(_separator));

    // Righe
    final dateFmt = DateFormat('dd/MM/yyyy');

    for (final p in prospects) {
      final row = [
        _escape(p.name),
        _escape(p.address),
        _escape(p.province),
        _escape(p.phone ?? ''),
        _escape(p.website ?? ''),
        _escape(p.status.label),
        _escape(p.notes ?? ''),
        dateFmt.format(p.createdAt),
        p.lastContactAt != null ? dateFmt.format(p.lastContactAt!) : '',
        _escape(p.businessType ?? ''),
        p.distanceMeters != null
            ? (p.distanceMeters! / 1000).toStringAsFixed(2)
            : '',
      ];
      buf.writeln(row.join(_separator));
    }

    return buf.toString();
  }

  /// Racchiude il valore tra virgolette se contiene separatori o virgolette
  static String _escape(String value) {
    if (value.contains(_separator) ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static Future<File> _writeFile(String content) async {
    final dir = await getTemporaryDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/prospect_toscana_$dateStr.csv');
    await file.writeAsString(content, encoding: const Utf8Codec());
    return file;
  }

  static Future<void> _share(File file, int count, String? label) async {
    final labelStr = label != null ? ' ($label)' : '';
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: 'Prospect Toscana$labelStr',
      text: '$count prospect esportati – CRM Toscana\n'
          'Apri con Excel: Dati → Recupera dati → Da testo/CSV → Separatore: punto e virgola',
    );
  }
}
