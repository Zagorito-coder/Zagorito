import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:spots_app/data/coastal_cities.dart';
import 'package:spots_app/models.dart';
import 'package:spots_app/utils/city_spot_search.dart';

void main() {
  test('la recherche de ville ignore la casse, les accents et les tirets', () {
    expect(
      CitySpotSearch.matchingCities('bejaia').single.name,
      'Béjaïa',
    );
    expect(
      CitySpotSearch.matchingCities('AL HOCEIMA').single.name,
      'Al Hoceïma',
    );
    expect(
      CitySpotSearch.matchingCities('port said').single.name,
      'Port-Saïd',
    );
  });

  test('les villes homonymes restent distinguées par leur pays', () {
    final tripoli = CitySpotSearch.matchingCities('Tripoli');

    expect(tripoli, hasLength(2));
    expect(tripoli.map((city) => city.iso), containsAll(['LB', 'LY']));
  });

  test('les 20 zones météo marocaines sont synchronisées avec la recherche',
      () {
    expect(moroccoWeatherSearchAreas, hasLength(20));
    expect(
      mapSearchLocations.length,
      coastalCities.length + moroccoWeatherSearchAreas.length,
    );

    for (final area in moroccoWeatherSearchAreas) {
      expect(area.isRegionalSearchArea, isTrue);
      expect(
        CitySpotSearch.matchingCities(area.name).map((item) => item.name),
        contains(area.name),
      );
    }
  });

  test('les variantes Akhfenir, Jebha et Laayoune retrouvent leur zone', () {
    expect(
      CitySpotSearch.matchingCities('Tarfaya Akhfenir').single.name,
      'Corridor Tarfaya–Akhfennir',
    );
    expect(
      CitySpotSearch.matchingCities('Jebha').single.name,
      'Littoral de Chefchaouen — secteur Jabha',
    );
    expect(
      CitySpotSearch.matchingCities('Laayoune Boujdour').single.name,
      'Corridor Laâyoune–Boujdour',
    );
  });

  test('les spots dans les 30 km sont triés depuis le centre-ville', () {
    const city = CoastalCity(
      name: 'Ville test',
      country: 'Pays test',
      iso: 'XX',
      lat: 33.5731,
      lon: -7.5898,
    );
    const closest = Spot(
      id: 'closest',
      name: 'Spot proche',
      latitude: 33.58,
      longitude: -7.60,
      location: LatLng(33.58, -7.60),
    );
    const nearby = Spot(
      id: 'nearby',
      name: 'Spot dans le rayon',
      latitude: 33.5731,
      longitude: -7.79,
      location: LatLng(33.5731, -7.79),
    );
    const outside = Spot(
      id: 'outside',
      name: 'Spot hors rayon',
      latitude: 33.5731,
      longitude: -8.10,
      location: LatLng(33.5731, -8.10),
    );

    final results = CitySpotSearch.spotsAroundCity(
      city,
      const [outside, nearby, closest],
    );

    expect(results.map((spot) => spot.id), ['closest', 'nearby']);
    expect(
      CitySpotSearch.distanceFromCityKm(city, closest),
      lessThan(CitySpotSearch.distanceFromCityKm(city, nearby)),
    );
  });

  test('la recherche de spot devient elle aussi insensible aux accents', () {
    const spot = Spot(
      id: 'accented',
      name: 'Plage de Témara',
      latitude: 33.92,
      longitude: -6.96,
      location: LatLng(33.92, -6.96),
    );

    expect(
      CitySpotSearch.matchingSpots('temara', const [spot]),
      const [spot],
    );
  });

  test('la recherche riche accepte pays, poissons et coordonnées', () {
    const fishSpot = Spot(
      id: 'fish-search',
      name: 'Pointe Atlantique',
      latitude: 29.36693,
      longitude: -10.18696,
      location: LatLng(29.36693, -10.18696),
      fishTypes: ['Loup-bar', 'Sar'],
    );

    expect(
      CitySpotSearch.matchingCities('Maroc Sidi Ifni').first.name,
      'Sidi Ifni',
    );
    expect(
      CitySpotSearch.matchingSpots('loup bar', const [fishSpot]),
      const [fishSpot],
    );
    expect(
      CitySpotSearch.matchingSpots(
        '29.36693,-10.18696',
        const [fishSpot],
      ),
      const [fishSpot],
    );
  });

  test(
      'une correspondance exacte est classée avant une correspondance partielle',
      () {
    const exact = CoastalCity(
      name: 'Safi',
      country: 'Maroc',
      iso: 'MA',
      lat: 32.2994,
      lon: -9.2372,
    );
    const partial = CoastalCity(
      name: 'As Safi Nord',
      country: 'Maroc',
      iso: 'MA',
      lat: 32.4,
      lon: -9.2,
    );

    expect(
      CitySpotSearch.matchingCities(
        'Safi',
        cities: const [partial, exact],
      ),
      const [exact, partial],
    );
  });
}
