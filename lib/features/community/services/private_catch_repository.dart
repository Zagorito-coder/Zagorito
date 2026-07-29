import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:spots_app/features/community/models/private_catch.dart';
import 'package:spots_app/features/community/services/community_photo_processor.dart';

class PrivateCatchRepository extends ChangeNotifier {
  PrivateCatchRepository._();

  static final instance = PrivateCatchRepository._();
  static const _databaseName = 'community_private_catches.db';
  static const _table = 'private_catches';

  final CommunityPhotoProcessor _photoProcessor =
      const CommunityPhotoProcessor();

  Database? _database;
  String? _ownerUid;
  Directory? _photoDirectory;
  List<PrivateCatch> _items = const [];
  bool _isLoading = false;
  Object? _lastError;

  List<PrivateCatch> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;

  Future<void> initialize() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      lock();
      throw const PrivateCatchException(
        PrivateCatchFailure.authenticationRequired,
      );
    }
    if (_database != null && _ownerUid == user.uid) {
      await reload();
      return;
    }
    _setLoading(true);
    try {
      _ownerUid = user.uid;
      final supportDirectory = await getApplicationSupportDirectory();
      final ownerDirectory =
          sha256.convert(utf8.encode(user.uid)).toString().substring(0, 32);
      final photoDirectory = Directory(
        path.join(
          supportDirectory.path,
          'community',
          'private_catches',
          ownerDirectory,
        ),
      );
      await photoDirectory.create(recursive: true);
      _photoDirectory = photoDirectory;

      final databasePath = path.join(
        await getDatabasesPath(),
        _databaseName,
      );
      _database = await openDatabase(
        databasePath,
        version: 2,
        onCreate: (database, _) async {
          await database.execute('''
            CREATE TABLE $_table (
              id TEXT PRIMARY KEY,
              owner_uid TEXT NOT NULL,
              photo_path TEXT NOT NULL,
              species TEXT NOT NULL,
              weight_kg REAL NOT NULL,
              spot_name TEXT NOT NULL,
              latitude REAL,
              longitude REAL,
              montage TEXT NOT NULL,
              bait TEXT NOT NULL,
              notes TEXT NOT NULL,
              advice TEXT NOT NULL,
              caught_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              published_post_id TEXT,
              published_at INTEGER
            )
          ''');
        },
        onUpgrade: (database, oldVersion, _) async {
          if (oldVersion < 2) {
            await database.execute(
              "ALTER TABLE $_table "
              "ADD COLUMN owner_uid TEXT NOT NULL DEFAULT ''",
            );
          }
        },
      );
      await _reloadFromDatabase();
      await _removeOrphanPhotos();
      _lastError = null;
    } catch (error, stackTrace) {
      _lastError = error;
      debugPrint(
        '[PrivateCatchRepository] Initialization failed: $error\n$stackTrace',
      );
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> reload() async {
    _setLoading(true);
    try {
      await _reloadFromDatabase();
      _lastError = null;
    } catch (error, stackTrace) {
      _lastError = error;
      debugPrint('[PrivateCatchRepository] Reload failed: $error\n$stackTrace');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<PrivateCatch> create(PrivateCatchDraft draft) async {
    await _ensureInitialized();
    _validateDraft(draft);
    if (_items.length >= PrivateCatch.maximumItems) {
      throw const PrivateCatchException(PrivateCatchFailure.limitReached);
    }

    final processed = await _photoProcessor.process(draft.photoBytes);
    if (processed.bytes.lengthInBytes > PrivateCatch.maximumPhotoBytes) {
      throw const PrivateCatchException(PrivateCatchFailure.invalidPhoto);
    }

    final id = _newId();
    final now = DateTime.now();
    final finalFile = File(path.join(_photoDirectory!.path, '$id.jpg'));
    final temporaryFile = File('${finalFile.path}.tmp');
    try {
      await temporaryFile.writeAsBytes(processed.bytes, flush: true);
      await temporaryFile.rename(finalFile.path);

      final item = PrivateCatch(
        id: id,
        ownerUid: _ownerUid!,
        photoPath: finalFile.path,
        species: draft.species.trim(),
        weightKg: draft.weightKg,
        spotName: draft.spotName.trim(),
        latitude: draft.latitude,
        longitude: draft.longitude,
        montage: draft.montage.trim(),
        bait: draft.bait.trim(),
        notes: draft.notes.trim(),
        advice: draft.advice.trim(),
        caughtAt: draft.caughtAt,
        createdAt: now,
      );
      await _database!.insert(
        _table,
        item.toDatabase(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await _reloadFromDatabase();
      return item;
    } catch (error, stackTrace) {
      await _deleteIfExists(temporaryFile);
      await _deleteIfExists(finalFile);
      debugPrint('[PrivateCatchRepository] Create failed: $error\n$stackTrace');
      if (error is PrivateCatchException) rethrow;
      throw const PrivateCatchException(PrivateCatchFailure.unavailable);
    }
  }

  Future<void> update(PrivateCatch item) async {
    await _ensureInitialized();
    if (item.ownerUid != _ownerUid) {
      throw const PrivateCatchException(PrivateCatchFailure.unavailable);
    }
    _validateItem(item);
    final updated = await _database!.update(
      _table,
      item.toDatabase(),
      where: 'id = ? AND owner_uid = ?',
      whereArgs: [item.id, _ownerUid],
    );
    if (updated != 1) {
      throw const PrivateCatchException(PrivateCatchFailure.unavailable);
    }
    await _reloadFromDatabase();
  }

  Future<void> markPublished({
    required String privateCatchId,
    required String postId,
    required DateTime publishedAt,
  }) async {
    await _ensureInitialized();
    final updated = await _database!.update(
      _table,
      {
        'published_post_id': postId,
        'published_at': publishedAt.millisecondsSinceEpoch,
      },
      where: 'id = ? AND owner_uid = ?',
      whereArgs: [privateCatchId, _ownerUid],
    );
    if (updated != 1) {
      throw const PrivateCatchException(PrivateCatchFailure.unavailable);
    }
    await _reloadFromDatabase();
  }

  Future<void> clearPublicationForPost(String postId) async {
    await _ensureInitialized();
    await _database!.update(
      _table,
      {
        'published_post_id': null,
        'published_at': null,
      },
      where: 'owner_uid = ? AND published_post_id = ?',
      whereArgs: [_ownerUid, postId],
    );
    await _reloadFromDatabase();
  }

  Future<void> delete(PrivateCatch item) async {
    await _ensureInitialized();
    if (item.ownerUid != _ownerUid) return;
    final deleted = await _database!.delete(
      _table,
      where: 'id = ? AND owner_uid = ?',
      whereArgs: [item.id, _ownerUid],
    );
    if (deleted != 1) return;
    await _deleteIfExists(File(item.photoPath));
    await _reloadFromDatabase();
  }

  Future<void> clearAll() async {
    await _ensureInitialized();
    final snapshot = List<PrivateCatch>.from(_items);
    await _database!.delete(
      _table,
      where: 'owner_uid = ?',
      whereArgs: [_ownerUid],
    );
    for (final item in snapshot) {
      await _deleteIfExists(File(item.photoPath));
    }
    await _reloadFromDatabase();
  }

  Future<Uint8List> readPhoto(PrivateCatch item) async {
    final bytes = await File(item.photoPath).readAsBytes();
    if (bytes.isEmpty || bytes.lengthInBytes > PrivateCatch.maximumPhotoBytes) {
      throw const PrivateCatchException(PrivateCatchFailure.invalidPhoto);
    }
    return bytes;
  }

  Future<void> _ensureInitialized() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (_database == null || uid == null || uid != _ownerUid) {
      await initialize();
    }
  }

  Future<void> _reloadFromDatabase() async {
    final rows = await _database!.query(
      _table,
      where: 'owner_uid = ?',
      whereArgs: [_ownerUid],
      orderBy: 'caught_at DESC, created_at DESC',
    );
    _items = rows.map(PrivateCatch.fromDatabase).toList(growable: false);
    notifyListeners();
  }

  Future<void> _removeOrphanPhotos() async {
    final directory = _photoDirectory;
    if (directory == null || !await directory.exists()) return;
    final referenced = _items.map((item) => item.photoPath).toSet();
    await for (final entity in directory.list()) {
      if (entity is File &&
          !referenced.contains(entity.path) &&
          (entity.path.endsWith('.jpg') || entity.path.endsWith('.tmp'))) {
        await _deleteIfExists(entity);
      }
    }
  }

  void _validateDraft(PrivateCatchDraft draft) {
    _validateFields(
      species: draft.species,
      weightKg: draft.weightKg,
      spotName: draft.spotName,
      latitude: draft.latitude,
      longitude: draft.longitude,
      montage: draft.montage,
      bait: draft.bait,
      notes: draft.notes,
      advice: draft.advice,
    );
    if (draft.photoBytes.isEmpty) {
      throw const PrivateCatchException(PrivateCatchFailure.invalidPhoto);
    }
  }

  void _validateItem(PrivateCatch item) {
    _validateFields(
      species: item.species,
      weightKg: item.weightKg,
      spotName: item.spotName,
      latitude: item.latitude,
      longitude: item.longitude,
      montage: item.montage,
      bait: item.bait,
      notes: item.notes,
      advice: item.advice,
    );
  }

  void _validateFields({
    required String species,
    required double weightKg,
    required String spotName,
    required double? latitude,
    required double? longitude,
    required String montage,
    required String bait,
    required String notes,
    required String advice,
  }) {
    final hasValidCoordinates = (latitude == null && longitude == null) ||
        (latitude != null &&
            longitude != null &&
            latitude.isFinite &&
            longitude.isFinite &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180);
    if (species.trim().isEmpty ||
        species.trim().length > PrivateCatch.maximumSpeciesLength ||
        !weightKg.isFinite ||
        weightKg < PrivateCatch.minimumWeightKg ||
        weightKg > PrivateCatch.maximumWeightKg ||
        spotName.trim().length > PrivateCatch.maximumSpotNameLength ||
        montage.trim().length > PrivateCatch.maximumMontageLength ||
        bait.trim().length > PrivateCatch.maximumBaitLength ||
        notes.trim().length > PrivateCatch.maximumNotesLength ||
        advice.trim().length > PrivateCatch.maximumAdviceLength ||
        !hasValidCoordinates) {
      throw const PrivateCatchException(PrivateCatchFailure.invalidData);
    }
  }

  static String _newId() {
    final random = Random.secure();
    final entropy = List<int>.generate(24, (_) => random.nextInt(256));
    final payload = utf8.encode(
      '${DateTime.now().microsecondsSinceEpoch}:${base64Url.encode(entropy)}',
    );
    return base64UrlEncode(sha256.convert(payload).bytes)
        .replaceAll('=', '')
        .substring(0, 32);
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('[PrivateCatchRepository] File cleanup deferred: $error');
    }
  }

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void lock() {
    _ownerUid = null;
    _photoDirectory = null;
    _items = const [];
    _lastError = null;
    _isLoading = false;
    notifyListeners();
  }
}
