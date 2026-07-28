import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spots_app/models/offline_map_region.dart';
import 'package:vector_map_tiles_pmtiles/vector_map_tiles_pmtiles.dart';

enum OfflineMapFailure {
  notConfigured,
  catalogUnavailable,
  invalidCatalog,
  downloadFailed,
  checksumMismatch,
  invalidArchive,
  installLimitReached,
}

class OfflineMapException implements Exception {
  const OfflineMapException(this.failure);

  final OfflineMapFailure failure;
}

class OfflineMapService extends ChangeNotifier {
  OfflineMapService._();

  static final OfflineMapService instance = OfflineMapService._();

  static const _productionBaseUrl =
      'https://boosterfish-offline-maps.boosterfish-maps.workers.dev/';
  static const _baseUrl = String.fromEnvironment(
    'OFFLINE_MAP_BASE_URL',
    defaultValue: _productionBaseUrl,
  );
  static const _allowInsecureUrl =
      bool.fromEnvironment('ALLOW_INSECURE_OFFLINE_MAPS');
  static const _activeRegionKey = 'offline_map_active_region';
  static const _activeFileKey = 'offline_map_active_file';
  static const _catalogFileName = 'catalog.json';
  static const _userAgent = 'BoosterFish/1.0 (offline maps)';

  Directory? _mapsDirectory;
  List<OfflineMapRegion> _regions = const [];
  Set<String> _installedRegionIds = const {};
  String? _activeRegionId;
  String? _activeFileName;
  Future<PmTilesVectorTileProvider>? _activeProvider;
  String? _downloadingRegionId;
  double _downloadProgress = 0;
  bool _cancelRequested = false;
  OfflineMapFailure? _lastFailure;
  bool _initialized = false;

  List<OfflineMapRegion> get regions => _regions;
  Set<String> get installedRegionIds => _installedRegionIds;
  String? get activeRegionId => _activeRegionId;
  OfflineMapRegion? get activeRegion {
    final id = _activeRegionId;
    if (id == null) return null;
    for (final region in _regions) {
      if (region.id == id) return region;
    }
    return null;
  }

  Future<PmTilesVectorTileProvider>? get activeProvider => _activeProvider;
  String? get downloadingRegionId => _downloadingRegionId;
  double get downloadProgress => _downloadProgress;
  OfflineMapFailure? get lastFailure => _lastFailure;
  bool get isConfigured => _baseUri != null;
  bool get hasActiveMap => _activeProvider != null;

  Uri? get _baseUri {
    final value = _baseUrl.trim();
    if (value.isEmpty) return null;
    final normalized = value.endsWith('/') ? value : '$value/';
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAuthority) return null;
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && _allowInsecureUrl)) {
      return null;
    }
    return uri;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    final supportDirectory = await getApplicationSupportDirectory();
    _mapsDirectory = Directory('${supportDirectory.path}/offline_maps');
    await _mapsDirectory!.create(recursive: true);
    await _loadCachedCatalog();

    final preferences = await SharedPreferences.getInstance();
    _activeRegionId = preferences.getString(_activeRegionKey);
    _activeFileName = preferences.getString(_activeFileKey);
    await _refreshInstalledRegions();
    await _restoreActiveProvider();
    _initialized = true;
  }

  Future<void> refreshCatalog() async {
    await initialize();
    final baseUri = _baseUri;
    if (baseUri == null) {
      _setFailure(OfflineMapFailure.notConfigured);
      return;
    }

    try {
      final response = await http.get(
        baseUri.resolve('manifest.json'),
        headers: const {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != HttpStatus.ok) {
        throw const OfflineMapException(
          OfflineMapFailure.catalogUnavailable,
        );
      }

      final catalog = _parseCatalog(response.body);
      final catalogFile = File('${_mapsDirectory!.path}/$_catalogFileName');
      final temporaryFile = File('${catalogFile.path}.download');
      await temporaryFile.writeAsString(response.body, flush: true);
      if (await catalogFile.exists()) await catalogFile.delete();
      await temporaryFile.rename(catalogFile.path);

      _regions = catalog.regions;
      _lastFailure = null;
      await _refreshInstalledRegions();
      notifyListeners();
    } on OfflineMapException catch (error) {
      _setFailure(error.failure);
    } on FormatException {
      _setFailure(OfflineMapFailure.invalidCatalog);
    } catch (error, stackTrace) {
      debugPrint('[OfflineMapService] Catalog error: $error\n$stackTrace');
      _setFailure(OfflineMapFailure.catalogUnavailable);
    }
  }

  bool isInstalled(OfflineMapRegion region) {
    return _installedRegionIds.contains(region.id);
  }

  bool canDownload(OfflineMapRegion region) {
    return OfflineMapInstallPolicy.canInstall(
      installedRegionIds: _installedRegionIds,
      requestedRegionId: region.id,
    );
  }

  Future<void> download(OfflineMapRegion region) async {
    await initialize();
    if (!region.isAllowed) {
      throw const OfflineMapException(OfflineMapFailure.invalidCatalog);
    }
    if (!canDownload(region)) {
      throw const OfflineMapException(
        OfflineMapFailure.installLimitReached,
      );
    }
    final baseUri = _baseUri;
    if (baseUri == null) {
      throw const OfflineMapException(OfflineMapFailure.notConfigured);
    }
    if (_downloadingRegionId != null) return;

    _downloadingRegionId = region.id;
    _downloadProgress = 0;
    _cancelRequested = false;
    _lastFailure = null;
    notifyListeners();

    final finalFile = _fileFor(region.fileName);
    final partialFile = File('${finalFile.path}.download');
    final client = http.Client();
    IOSink? sink;

    try {
      var downloadedBytes =
          await partialFile.exists() ? await partialFile.length() : 0;
      if (downloadedBytes >= region.sizeBytes) {
        await partialFile.delete();
        downloadedBytes = 0;
      }

      final request = http.Request('GET', region.downloadUri(baseUri));
      request.headers[HttpHeaders.userAgentHeader] = _userAgent;
      if (downloadedBytes > 0) {
        request.headers[HttpHeaders.rangeHeader] = 'bytes=$downloadedBytes-';
      }

      final response =
          await client.send(request).timeout(const Duration(seconds: 20));
      final canResume = response.statusCode == HttpStatus.partialContent;
      if (response.statusCode != HttpStatus.ok && !canResume) {
        throw const OfflineMapException(OfflineMapFailure.downloadFailed);
      }
      if (!canResume && downloadedBytes > 0) {
        await partialFile.delete();
        downloadedBytes = 0;
      }

      sink = partialFile.openWrite(
        mode: canResume ? FileMode.append : FileMode.write,
      );
      await for (final chunk in response.stream) {
        if (_cancelRequested) throw const _DownloadCancelled();
        sink.add(chunk);
        downloadedBytes += chunk.length;
        _downloadProgress =
            (downloadedBytes / region.sizeBytes).clamp(0.0, 1.0);
        notifyListeners();
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (downloadedBytes != region.sizeBytes) {
        throw const OfflineMapException(OfflineMapFailure.downloadFailed);
      }
      final digest = await sha256.bind(partialFile.openRead()).first;
      if (digest.toString() != region.sha256Digest) {
        await partialFile.delete();
        throw const OfflineMapException(OfflineMapFailure.checksumMismatch);
      }

      try {
        await PmTilesVectorTileProvider.fromSource(partialFile.path);
      } catch (error) {
        await partialFile.delete();
        throw const OfflineMapException(OfflineMapFailure.invalidArchive);
      }

      if (await finalFile.exists()) await finalFile.delete();
      await partialFile.rename(finalFile.path);
      await _refreshInstalledRegions();
      await activate(region);
      _lastFailure = null;
    } on _DownloadCancelled {
      // Keep the partial file so the next attempt can resume safely.
    } on OfflineMapException catch (error) {
      _lastFailure = error.failure;
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('[OfflineMapService] Download error: $error\n$stackTrace');
      _lastFailure = OfflineMapFailure.downloadFailed;
      throw const OfflineMapException(OfflineMapFailure.downloadFailed);
    } finally {
      await sink?.close();
      client.close();
      _downloadingRegionId = null;
      _downloadProgress = 0;
      _cancelRequested = false;
      notifyListeners();
    }
  }

  void cancelDownload() {
    if (_downloadingRegionId == null) return;
    _cancelRequested = true;
  }

  Future<void> activate(OfflineMapRegion region) async {
    await initialize();
    final file = _fileFor(region.fileName);
    if (!await file.exists()) {
      throw const OfflineMapException(OfflineMapFailure.invalidArchive);
    }

    final provider = PmTilesVectorTileProvider.fromSource(file.path);
    await provider;
    _activeRegionId = region.id;
    _activeFileName = region.fileName;
    _activeProvider = provider;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_activeRegionKey, region.id);
    await preferences.setString(_activeFileKey, region.fileName);
    notifyListeners();
  }

  Future<void> delete(OfflineMapRegion region) async {
    await initialize();
    if (_downloadingRegionId == region.id) return;
    if (_activeRegionId == region.id) await _clearActiveRegion();

    final file = _fileFor(region.fileName);
    final partialFile = File('${file.path}.download');
    if (await file.exists()) await file.delete();
    if (await partialFile.exists()) await partialFile.delete();
    await _refreshInstalledRegions();
    notifyListeners();
  }

  int get installedBytes {
    return _regions
        .where((region) => _installedRegionIds.contains(region.id))
        .fold(0, (total, region) => total + region.sizeBytes);
  }

  OfflineMapCatalog _parseCatalog(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid offline map manifest');
    }
    return OfflineMapCatalog.fromJson(decoded);
  }

  Future<void> _loadCachedCatalog() async {
    final file = File('${_mapsDirectory!.path}/$_catalogFileName');
    if (!await file.exists()) return;
    try {
      final catalog = _parseCatalog(await file.readAsString());
      _regions = catalog.regions;
    } catch (error) {
      debugPrint('[OfflineMapService] Cached catalog ignored: $error');
    }
  }

  Future<void> _refreshInstalledRegions() async {
    final installed = <String>{};
    for (final region in _regions) {
      final file = _fileFor(region.fileName);
      if (await file.exists() && await file.length() == region.sizeBytes) {
        installed.add(region.id);
      }
    }
    _installedRegionIds = Set.unmodifiable(installed);
  }

  Future<void> _restoreActiveProvider() async {
    final fileName = _activeFileName;
    if (_activeRegionId == null || fileName == null) return;
    final file = _fileFor(fileName);
    if (!await file.exists()) {
      await _clearActiveRegion();
      return;
    }
    try {
      final provider = PmTilesVectorTileProvider.fromSource(file.path);
      await provider;
      _activeProvider = provider;
    } catch (error) {
      debugPrint('[OfflineMapService] Invalid active map: $error');
      await _clearActiveRegion();
    }
  }

  Future<void> _clearActiveRegion() async {
    _activeRegionId = null;
    _activeFileName = null;
    _activeProvider = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_activeRegionKey);
    await preferences.remove(_activeFileKey);
  }

  File _fileFor(String fileName) {
    return File('${_mapsDirectory!.path}/$fileName');
  }

  void _setFailure(OfflineMapFailure failure) {
    _lastFailure = failure;
    notifyListeners();
  }
}

class _DownloadCancelled implements Exception {
  const _DownloadCancelled();
}
