import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:spots_app/models/offline_map_region.dart';
import 'package:spots_app/services/offline_map_service.dart';

class _TrackingClient extends http.BaseClient {
  _TrackingClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      handler;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() {
    closed = true;
    super.close();
  }
}

OfflineMapRegion _region() => OfflineMapRegion(
      id: 'audit-ma',
      countryCode: 'MA',
      continent: OfflineMapContinent.africa,
      names: const {'fr': 'Audit'},
      fileName: 'audit-ma.pmtiles',
      sizeBytes: 100,
      sha256Digest: List.filled(64, '0').join(),
      minZoom: 0,
      maxZoom: 5,
      spotCount: 40,
      bounds: const OfflineMapBounds(
        minLongitude: -12,
        minLatitude: 28,
        maxLongitude: -5,
        maxLatitude: 36,
      ),
    );

Future<Directory> _temporaryMapsDirectory() async {
  final root = await Directory.systemTemp.createTemp('boosterfish-map-test-');
  final maps = Directory('${root.path}/offline_maps');
  await maps.create(recursive: true);
  return maps;
}

void main() {
  test('Annuler interrompt un flux réseau silencieux et libère le service',
      () async {
    final mapsDirectory = await _temporaryMapsDirectory();
    addTearDown(() => mapsDirectory.parent.delete(recursive: true));

    final responseBody = StreamController<List<int>>();
    addTearDown(responseBody.close);
    final responseListening = Completer<void>();
    responseBody.onListen = responseListening.complete;

    late _TrackingClient client;
    client = _TrackingClient((request) async {
      expect(request, isA<http.AbortableRequest>());
      final abortable = request as http.AbortableRequest;
      unawaited(
        abortable.abortTrigger!.then((_) {
          responseBody.addError(http.RequestAbortedException(request.url));
        }),
      );
      return http.StreamedResponse(responseBody.stream, HttpStatus.ok);
    });
    final service = OfflineMapService.forTesting(
      mapsDirectory: mapsDirectory,
      httpClientFactory: () => client,
      downloadTimeout: const Duration(seconds: 2),
    );
    addTearDown(service.dispose);

    final download = service.download(_region());
    await responseListening.future.timeout(const Duration(seconds: 1));
    service.cancelDownload();
    await download.timeout(const Duration(seconds: 1));

    expect(service.downloadingRegionId, isNull);
    expect(service.downloadProgress, 0);
    expect(service.lastFailure, isNull);
    expect(client.closed, isTrue);
  });

  test('un corps HTTP sans données expire et libère toutes les ressources',
      () async {
    final mapsDirectory = await _temporaryMapsDirectory();
    addTearDown(() => mapsDirectory.parent.delete(recursive: true));

    final responseBody = StreamController<List<int>>();
    addTearDown(responseBody.close);
    late _TrackingClient client;
    client = _TrackingClient(
      (_) async => http.StreamedResponse(
        responseBody.stream,
        HttpStatus.ok,
      ),
    );
    final service = OfflineMapService.forTesting(
      mapsDirectory: mapsDirectory,
      httpClientFactory: () => client,
      downloadTimeout: const Duration(milliseconds: 30),
    );
    addTearDown(service.dispose);

    await expectLater(
      service.download(_region()),
      throwsA(
        isA<OfflineMapException>().having(
          (error) => error.failure,
          'failure',
          OfflineMapFailure.downloadFailed,
        ),
      ),
    );

    expect(service.downloadingRegionId, isNull);
    expect(service.downloadProgress, 0);
    expect(service.lastFailure, OfflineMapFailure.downloadFailed);
    expect(client.closed, isTrue);
  });
}
