// ============================================================
//  services/spot_service.dart — Chargement et cache des spots
//  AES-256-CBC : fichier = IV(16B) + ciphertext
// ============================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:encrypt/encrypt.dart' as enc;
import '../models.dart';

class SpotService {
  SpotService._();

  static Future<File> get _cacheFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/spots_cache_v4.json');
  }

  static Future<R> _computeOrRun<Q, R>(R Function(Q) c, Q m) =>
      kIsWeb ? Future<R>.sync(() => c(m)) : compute(c, m);

  static Future<List<Spot>> loadFromCache() async {
    try {
      final f = await _cacheFile;
      return f.existsSync()
          ? await _computeOrRun(_parseJson, await f.readAsString())
          : [];
    } catch (e) {
      return [];
    }
  }

  static List<Spot> _parseJson(String c) =>
      (jsonDecode(c) as List)
          .map((e) => Spot.fromJson(e as Map<String, dynamic>))
          .toList();

  static Future<void> saveToCache(List<Spot> s) async {
    try {
      await (await _cacheFile).writeAsString(
        await _computeOrRun(
          (list) => jsonEncode(list.map((e) => e.toJson()).toList()),
          s,
        ),
      );
    } catch (_) {}
  }

  // Clé AES-256 générée par tools/encrypt_spots.py
  static const String _encKey = 'q/F+3pnu668/hPnjF96uTqZH+7E24ppnH+53+rwdya0=';

  static Future<List<Spot>> loadFromCsv() async {
    debugPrint('[SpotService] loadFromCsv...');

    final raw = await rootBundle.load('assets/spots.csv.enc');
    final bytes = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    debugPrint('[SpotService] Fichier chargé: ${bytes.length} bytes');

    // Tout le déchiffrement AES + parsing CSV dans un isolate séparé
    final spots = await _computeOrRun(_decryptAndParse, bytes);
    debugPrint('[SpotService] Spots parsés: ${spots.length}');
    return spots;
  }

  static List<Spot> _decryptAndParse(Uint8List bytes) {
    final ivBytes = bytes.sublist(0, 16);
    final ct = bytes.sublist(16);
    final key = enc.Key.fromBase64(_encKey);
    final iv = enc.IV(ivBytes);
    final cipher = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final decrypted =
        Uint8List.fromList(cipher.decryptBytes(enc.Encrypted(ct), iv: iv));
    final csv = utf8.decode(decrypted);
    return _parseCsv(csv);
  }

  static List<Spot> _parseCsv(String raw) {
    final lines = raw.split('\n');
    final spots = <Spot>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      try {
        spots.add(Spot.fromCsv(line, index: i));
      } catch (_) {
        debugPrint('[SpotService] Skipped CSV line $i: $line');
      }
    }
    return spots;
  }
}