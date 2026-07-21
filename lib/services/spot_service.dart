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
import 'package:crypto/crypto.dart';
import '../models.dart';

class SpotService {
  SpotService._();

  static const String _assetPath = 'assets/spots.csv.enc';
  static const int _cacheSchemaVersion = 5;

  // La valeur est injectee au build avec --dart-define-from-file=.env.
  // Elle n'est jamais lue depuis un fichier embarque dans l'application.
  static const String _encKey = String.fromEnvironment('CSV_ENCRYPTION_KEY');

  static Future<_BundledSpotAsset>? _bundledAssetFuture;

  static Future<File> get _cacheFile async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/spots_cache_v5.json');
  }

  static Future<R> _computeOrRun<Q, R>(R Function(Q) c, Q m) =>
      kIsWeb ? Future<R>.sync(() => c(m)) : compute(c, m);

  /// Charge le catalogue embarque et n'utilise le cache que s'il correspond
  /// exactement a l'asset de cette version de l'application.
  static Future<List<Spot>> loadSpots() async {
    final asset = await _loadBundledAsset();
    final cached = await _loadFromCache(asset.sha256);
    if (cached.isNotEmpty) return cached;

    final spots = await _computeOrRun(_decryptAndParse, asset.bytes);
    if (spots.isEmpty) {
      throw const FormatException('Le catalogue des spots est vide.');
    }

    await _saveToCache(spots, asset.sha256);
    return spots;
  }

  static Future<_BundledSpotAsset> _loadBundledAsset() {
    return _bundledAssetFuture ??= _readBundledAsset();
  }

  static Future<_BundledSpotAsset> _readBundledAsset() async {
    final raw = await rootBundle.load(_assetPath);
    final view = raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    final bytes = Uint8List.fromList(view);
    return _BundledSpotAsset(
      bytes: bytes,
      sha256: sha256.convert(bytes).toString(),
    );
  }

  static Future<List<Spot>> _loadFromCache(String assetSha256) async {
    try {
      final f = await _cacheFile;
      if (!await f.exists()) return [];

      return await _computeOrRun(_parseCache, {
        'raw': await f.readAsString(),
        'assetSha256': assetSha256,
      });
    } catch (e) {
      debugPrint('[SpotService] Cache ignore: $e');
      return [];
    }
  }

  static List<Spot> _parseCache(Map<String, String> input) {
    final decoded = jsonDecode(input['raw']!);
    if (decoded is! Map<String, dynamic> ||
        decoded['schemaVersion'] != _cacheSchemaVersion ||
        decoded['assetSha256'] != input['assetSha256']) {
      return [];
    }

    final rows = decoded['spots'];
    if (rows is! List<dynamic>) return [];
    return rows
        .map((e) => Spot.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<void> _saveToCache(
    List<Spot> spots,
    String assetSha256,
  ) async {
    try {
      final payload = <String, dynamic>{
        'schemaVersion': _cacheSchemaVersion,
        'assetSha256': assetSha256,
        'spots': spots.map((e) => e.toJson()).toList(),
      };
      final encoded = await _computeOrRun(jsonEncode, payload);
      await (await _cacheFile).writeAsString(encoded, flush: true);
    } catch (e) {
      debugPrint('[SpotService] Erreur sauvegarde cache: $e');
    }
  }

  static List<Spot> _decryptAndParse(Uint8List bytes) {
    try {
      if (bytes.length <= 16) {
        throw const FormatException('Asset chiffre incomplet.');
      }

      final keyBytes = base64Decode(_encKey);
      if (keyBytes.length != 32) {
        throw const FormatException('Cle AES-256 absente ou invalide.');
      }

      final ivBytes = bytes.sublist(0, 16);
      final ct = bytes.sublist(16);
      final key = enc.Key(Uint8List.fromList(keyBytes));
      final iv = enc.IV(ivBytes);
      final cipher = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decrypted = Uint8List.fromList(
        cipher.decryptBytes(enc.Encrypted(ct), iv: iv),
      );
      return _parseCsv(utf8.decode(decrypted));
    } catch (e) {
      throw const FormatException(
        'Impossible de charger le catalogue des spots. '
        'Verifiez la configuration du build Release.',
      );
    }
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

class _BundledSpotAsset {
  final Uint8List bytes;
  final String sha256;

  const _BundledSpotAsset({required this.bytes, required this.sha256});
}
