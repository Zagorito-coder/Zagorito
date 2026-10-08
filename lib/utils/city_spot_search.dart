import 'package:latlong2/latlong.dart';
import 'package:spots_app/data/coastal_cities.dart';
import 'package:spots_app/models.dart';

/// Recherche locale de villes côtières et de spots proches.
///
/// Aucun appel réseau n'est effectué : les suggestions de villes proviennent
/// du catalogue embarqué et les distances sont calculées sur l'appareil.
abstract final class CitySpotSearch {
  static const double radiusKm = 30;
  static const int maximumCitySuggestions = 40;
  static const int maximumSpotSuggestions = 80;

  static const Distance _distance = Distance();

  static List<CoastalCity> matchingCities(
    String query, {
    List<CoastalCity> cities = mapSearchLocations,
  }) {
    final normalizedQuery = normalize(query);
    if (normalizedQuery.isEmpty) return const [];

    final matches = cities.where((city) {
      final primary = normalize(city.name);
      final searchable = normalize(
        '${city.name} ${city.searchAliases.join(' ')} ${city.country} '
        '${city.iso} ${city.lat} ${city.lon}',
      );
      return _matchRank(primary, searchable, normalizedQuery) != null;
    }).toList()
      ..sort((left, right) {
        final leftName = normalize(left.name);
        final rightName = normalize(right.name);
        final leftSearchable = normalize(
          '${left.name} ${left.searchAliases.join(' ')} ${left.country} '
          '${left.iso} ${left.lat} ${left.lon}',
        );
        final rightSearchable = normalize(
          '${right.name} ${right.searchAliases.join(' ')} ${right.country} '
          '${right.iso} ${right.lat} ${right.lon}',
        );
        final leftRank = _matchRank(leftName, leftSearchable, normalizedQuery)!;
        final rightRank =
            _matchRank(rightName, rightSearchable, normalizedQuery)!;
        if (leftRank != rightRank) return leftRank.compareTo(rightRank);
        final byName = leftName.compareTo(rightName);
        if (byName != 0) return byName;
        return left.iso.compareTo(right.iso);
      });

    if (matches.length <= maximumCitySuggestions) return matches;
    return matches.sublist(0, maximumCitySuggestions);
  }

  static List<Spot> matchingSpots(String query, List<Spot> spots) {
    return SpotSearchIndex(spots).search(query);
  }

  static List<Spot> spotsAroundCity(
    CoastalCity city,
    List<Spot> spots, {
    double radiusKm = radiusKm,
  }) {
    if (!radiusKm.isFinite || radiusKm <= 0) return const [];
    final center = LatLng(city.lat, city.lon);
    final distances = <Spot, double>{};

    for (final spot in spots) {
      if (!_hasValidCoordinates(spot)) continue;
      final distanceKm = _distance.as(
        LengthUnit.Kilometer,
        center,
        spot.location,
      );
      if (distanceKm.isFinite && distanceKm <= radiusKm) {
        distances[spot] = distanceKm;
      }
    }

    final nearby = distances.keys.toList()
      ..sort((left, right) {
        final byDistance = distances[left]!.compareTo(distances[right]!);
        if (byDistance != 0) return byDistance;
        return normalize(left.name).compareTo(normalize(right.name));
      });
    return nearby;
  }

  static double distanceFromCityKm(CoastalCity city, Spot spot) {
    if (!_hasValidCoordinates(spot)) return double.infinity;
    return _distance.as(
      LengthUnit.Kilometer,
      LatLng(city.lat, city.lon),
      spot.location,
    );
  }

  static String normalize(String value) {
    var normalized = value.trim().toLowerCase();
    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'œ': 'oe',
      'æ': 'ae',
      'أ': 'ا',
      'إ': 'ا',
      'آ': 'ا',
      'ٱ': 'ا',
      'ى': 'ي',
      'ؤ': 'و',
      'ئ': 'ي',
    };
    for (final replacement in replacements.entries) {
      normalized = normalized.replaceAll(replacement.key, replacement.value);
    }
    return normalized
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r"[-_'’]+"), ' ')
        .replaceAll(RegExp(r'[,;:/]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static int? _matchRank(
    String primary,
    String searchable,
    String normalizedQuery,
  ) {
    if (primary == normalizedQuery) return 0;
    if (primary.startsWith(normalizedQuery)) return 1;
    if (primary.contains(normalizedQuery)) return 2;
    if (searchable.contains(normalizedQuery)) return 3;

    final queryWords = normalizedQuery.split(' ');
    if (queryWords.every(searchable.contains)) return 4;
    return null;
  }

  static bool _hasValidCoordinates(Spot spot) =>
      spot.latitude.isFinite &&
      spot.longitude.isFinite &&
      spot.latitude >= -90 &&
      spot.latitude <= 90 &&
      spot.longitude >= -180 &&
      spot.longitude <= 180;
}

/// Index local immuable utilisé par la barre de recherche de la carte.
///
/// Les textes normalisés sont calculés une seule fois au chargement du
/// catalogue. Une frappe ne parcourt ensuite que ces chaînes déjà préparées et
/// ne renormalise plus les résultats pendant le tri.
final class SpotSearchIndex {
  final List<_IndexedSpot> _entries;

  SpotSearchIndex(Iterable<Spot> spots)
      : _entries = List<_IndexedSpot>.unmodifiable(
          spots.map(_IndexedSpot.new),
        );

  SpotSearchIndex.empty() : _entries = const [];

  List<Spot> search(String query) {
    final normalizedQuery = CitySpotSearch.normalize(query);
    if (normalizedQuery.isEmpty) return const [];

    final matches = <_RankedSpot>[];
    for (final entry in _entries) {
      final rank = CitySpotSearch._matchRank(
        entry.primary,
        entry.searchable,
        normalizedQuery,
      );
      if (rank != null) {
        matches.add(_RankedSpot(entry: entry, rank: rank));
      }
    }

    matches.sort((left, right) {
      final byRank = left.rank.compareTo(right.rank);
      if (byRank != 0) return byRank;
      final byName = left.entry.primary.compareTo(right.entry.primary);
      if (byName != 0) return byName;
      return left.entry.spot.id.compareTo(right.entry.spot.id);
    });

    final resultCount = matches.length < CitySpotSearch.maximumSpotSuggestions
        ? matches.length
        : CitySpotSearch.maximumSpotSuggestions;
    return List<Spot>.generate(
      resultCount,
      (index) => matches[index].entry.spot,
      growable: false,
    );
  }
}

final class _IndexedSpot {
  final Spot spot;
  final String primary;
  final String searchable;

  _IndexedSpot(Spot spot)
      : spot = spot,
        primary = CitySpotSearch.normalize(spot.name),
        searchable = CitySpotSearch.normalize(
          '${spot.name} ${spot.fishTypes.join(' ')} '
          '${spot.latitude} ${spot.longitude}',
        );
}

final class _RankedSpot {
  final _IndexedSpot entry;
  final int rank;

  const _RankedSpot({required this.entry, required this.rank});
}
