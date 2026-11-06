import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mindspace_nlp/features/spiritual_places/models/spiritual_place.dart';
import 'package:mindspace_nlp/features/spiritual_places/services/device_location_service.dart';
import 'package:mindspace_nlp/features/spiritual_places/services/spiritual_places_sync_service.dart';
import 'package:mindspace_nlp/features/spiritual_places/services/spiritual_zone_service.dart';
import 'package:mindspace_nlp/features/spiritual_places/utils/geojson_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DeviceLocationService.clearMockLocation();
  });

  group('GeoJSON Parsing & Coordinate Order Tests', () {
    test('Correctly parses GeoJSON Polygon coordinates with longitude first', () {
      final geoJson = {
        'type': 'Polygon',
        'coordinates': [
          [
            [73.5322, 22.4844], // [lon, lat]
            [73.5338, 22.4843],
            [73.5342, 22.4857],
            [73.5326, 22.4859],
            [73.5322, 22.4844],
          ]
        ]
      };

      final points = GeoJsonPolygonParser.parsePolygonCoordinates(geoJson);
      expect(points.length, 5);

      // Verify that longitude is mapped to LatLng.longitude and latitude to LatLng.latitude
      expect(points[0].latitude, 22.4844);
      expect(points[0].longitude, 73.5322);
      expect(points[2].latitude, 22.4857);
      expect(points[2].longitude, 73.5342);
    });

    test('Parses GeoJSON MultiPolygon correctly', () {
      final multiPoly = {
        'type': 'MultiPolygon',
        'coordinates': [
          [
            [
              [72.8500, 24.3311],
              [72.8522, 24.3310],
              [72.8524, 24.3329],
              [72.8502, 24.3330],
              [72.8500, 24.3311],
            ]
          ]
        ]
      };

      final points = GeoJsonPolygonParser.parsePolygonCoordinates(multiPoly);
      expect(points.length, 5);
      expect(points[0].latitude, 24.3311);
      expect(points[0].longitude, 72.8500);
    });

    test('Parses raw JSON string coordinates cleanly', () {
      const jsonString =
          '{"type":"Polygon","coordinates":[[[68.9666,22.2367],[68.9682,22.2366],[68.9684,22.2385],[68.9668,22.2386],[68.9666,22.2367]]]}';
      final points = GeoJsonPolygonParser.parsePolygonCoordinates(jsonString);
      expect(points.length, 5);
      expect(points[0].latitude, 22.2367);
      expect(points[0].longitude, 68.9666);
    });

    test('Handles malformed and empty GeoJSON gracefully without exceptions', () {
      expect(GeoJsonPolygonParser.parsePolygonCoordinates(null), isEmpty);
      expect(GeoJsonPolygonParser.parsePolygonCoordinates(''), isEmpty);
      expect(GeoJsonPolygonParser.parsePolygonCoordinates('invalid json'), isEmpty);
      expect(GeoJsonPolygonParser.parsePolygonCoordinates({}), isEmpty);
      expect(GeoJsonPolygonParser.parsePolygonCoordinates({'coordinates': []}), isEmpty);
    });

    test('Converts LatLng points back to valid GeoJSON closed polygon', () {
      final points = [
        const LatLng(22.0, 73.0),
        const LatLng(22.0, 74.0),
        const LatLng(23.0, 74.0),
        const LatLng(23.0, 73.0),
      ];

      final geoJson = GeoJsonPolygonParser.toGeoJsonPolygon(points);
      expect(geoJson['type'], 'Polygon');
      final coords = geoJson['coordinates'][0] as List;
      // Should have 5 coordinates because ring was closed
      expect(coords.length, 5);
      expect(coords.first, [73.0, 22.0]);
      expect(coords.last, [73.0, 22.0]);
    });
  });

  group('Point-in-Polygon Ray Casting & Boundary Edge Tests', () {
    // 1-degree square box around (lat 22.0 - 23.0, lon 73.0 - 74.0)
    final squarePolygon = [
      const LatLng(22.0, 73.0),
      const LatLng(22.0, 74.0),
      const LatLng(23.0, 74.0),
      const LatLng(23.0, 73.0),
      const LatLng(22.0, 73.0),
    ];

    test('Detects point strictly inside polygon', () {
      const insidePoint = LatLng(22.5, 73.5);
      expect(GeoJsonPolygonParser.isPointInsidePolygon(insidePoint, squarePolygon), isTrue);
    });

    test('Detects point strictly outside polygon', () {
      const outsidePoint = LatLng(21.5, 73.5);
      expect(GeoJsonPolygonParser.isPointInsidePolygon(outsidePoint, squarePolygon), isFalse);
    });

    test('Detects point exactly on polygon vertex (boundary case)', () {
      const vertexPoint = LatLng(22.0, 73.0);
      expect(GeoJsonPolygonParser.isPointInsidePolygon(vertexPoint, squarePolygon), isTrue);
    });

    test('Detects point on polygon perimeter edge segment (edge case)', () {
      const edgePoint = LatLng(22.5, 74.0); // Exactly on the eastern edge
      expect(GeoJsonPolygonParser.isPointInsidePolygon(edgePoint, squarePolygon), isTrue);
    });

    test('Detects point slightly outside polygon edge', () {
      const nearOutsidePoint = LatLng(22.5, 74.005);
      expect(GeoJsonPolygonParser.isPointInsidePolygon(nearOutsidePoint, squarePolygon), isFalse);
    });
  });

  group('SpiritualZoneService Dynamic Polygon Classification Tests', () {
    final customPlace = SpiritualPlace(
      id: 'custom_temple',
      name: 'Custom Shrine',
      region: 'Gujarat, India',
      latitude: 22.4850,
      longitude: 73.5330,
      category: 'Pilgrimage Shrine',
      description: 'Dynamic website boundary test shrine',
      highMultiplier: 2.5,
      lowMultiplier: 1.8,
      isPublished: true,
      highIntensityPolygon: const [
        LatLng(22.4840, 73.5320),
        LatLng(22.4840, 73.5340),
        LatLng(22.4860, 73.5340),
        LatLng(22.4860, 73.5320),
        LatLng(22.4840, 73.5320),
      ],
      lowIntensityPolygon: const [
        LatLng(22.4800, 73.5280),
        LatLng(22.4800, 73.5380),
        LatLng(22.4900, 73.5380),
        LatLng(22.4900, 73.5280),
        LatLng(22.4800, 73.5280),
      ],
    );

    test('Classifies High Intensity Zone when coordinates are inside inner polygon', () {
      // (22.4850, 73.5330) is inside both inner and outer
      final zone = SpiritualZoneService.getZone(customPlace, 22.4850, 73.5330);
      expect(zone, SpiritualZone.highIntensity);
      expect(SpiritualZoneService.getIntensityMultiplier(zone, customPlace), 2.5);
      expect(SpiritualZoneService.getZoneName(zone), 'High Intensity Zone');
    });

    test('Classifies Low Intensity Zone when inside outer polygon but outside inner', () {
      // (22.4880, 73.5350) is inside outer polygon, but outside inner polygon
      final zone = SpiritualZoneService.getZone(customPlace, 22.4880, 73.5350);
      expect(zone, SpiritualZone.lowIntensity);
      expect(SpiritualZoneService.getIntensityMultiplier(zone, customPlace), 1.8);
      expect(SpiritualZoneService.getZoneName(zone), 'Low Intensity Zone');
    });

    test('Classifies Outside Spiritual Zones when coordinates are outside both polygons', () {
      // (22.5000, 73.5500) is outside both polygons
      final zone = SpiritualZoneService.getZone(customPlace, 22.5000, 73.5500);
      expect(zone, SpiritualZone.outside);
      expect(SpiritualZoneService.getIntensityMultiplier(zone, customPlace), 1.0);
      expect(SpiritualZoneService.getZoneName(zone), 'Outside Spiritual Zones');
    });

    test('Separates straight-line distance from polygon containment', () {
      // Distance is calculated directly to reference pin (22.4850, 73.5330)
      final dist = SpiritualZoneService.calculateDistance(
        22.4880,
        73.5350,
        customPlace.latitude,
        customPlace.longitude,
      );

      expect(dist, greaterThan(350));
      expect(dist, lessThan(450));
    });
  });

  group('SpiritualPlacesSyncService API & Persistence Tests', () {
    test('Sync fetches published places from Laravel API and persists to cache', () async {
      final syncService = SpiritualPlacesSyncService();

      final mockApiResponse = jsonEncode({
        'data': [
          {
            'id': 'api_place_1',
            'name': 'Somnath Shrine API',
            'region': 'Gir Somnath',
            'latitude': 20.8880,
            'longitude': 70.4012,
            'category': 'Jyotirlinga',
            'description': 'Updated from website',
            'high_multiplier': 3.0,
            'low_multiplier': 2.0,
            'is_published': true,
            'high_intensity_polygon': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [70.4004, 20.8871],
                  [70.4020, 20.8870],
                  [70.4022, 20.8889],
                  [70.4006, 20.8890],
                  [70.4004, 20.8871],
                ]
              ]
            },
            'low_intensity_polygon': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [70.3940, 20.8820],
                  [70.4080, 20.8830],
                  [70.4090, 20.8950],
                  [70.3950, 20.8940],
                  [70.3940, 20.8820],
                ]
              ]
            }
          },
          {
            'id': 'unpublished_draft',
            'name': 'Draft Temple',
            'latitude': 21.0,
            'longitude': 71.0,
            'is_published': false, // Unpublished, should be excluded
          }
        ]
      });

      syncService.setMockClient(MockClient((request) async {
        return http.Response(mockApiResponse, 200);
      }));

      final success = await syncService.syncWithWebsite();
      expect(success, isTrue);

      final places = syncService.placesNotifier.value;
      expect(places.length, 1);
      expect(places[0].id, 'api_place_1');
      expect(places[0].name, 'Somnath Shrine API');
      expect(places[0].highMultiplier, 3.0);
      expect(places[0].highIntensityPolygon.length, 5);

      // Verify draft place was excluded
      expect(places.any((p) => p.id == 'unpublished_draft'), isFalse);
    });

    test('Preserves previously cached data when API call fails', () async {
      final syncService = SpiritualPlacesSyncService();

      // Seed cache first using successful mock response
      final seedPlaces = jsonEncode({
        'data': [
          {
            'id': 'place_seed_1',
            'name': 'Seed Temple',
            'latitude': 22.4850,
            'longitude': 73.5330,
            'category': 'Shakti Peeth',
            'description': 'Cached shrine',
            'is_published': true,
          }
        ]
      });
      syncService.setMockClient(MockClient((request) async {
        return http.Response(seedPlaces, 200);
      }));
      final seedSuccess = await syncService.syncWithWebsite();
      expect(seedSuccess, isTrue);
      expect(syncService.placesNotifier.value.isNotEmpty, isTrue);
      final initialCount = syncService.placesNotifier.value.length;

      // Mock an API failure (500 Internal Server Error)
      syncService.setMockClient(MockClient((request) async {
        return http.Response('Server Error', 500);
      }));

      final syncResult = await syncService.syncWithWebsite();
      expect(syncResult, isFalse);
      expect(syncService.isOfflineNotifier.value, isTrue);

      // Cached places must NOT be discarded
      expect(syncService.placesNotifier.value.length, initialCount);
    });
  });

  group('Developer Location Simulator Isolation Tests', () {
    test('Simulator is disabled by default and never silently replaces GPS', () {
      expect(DeviceLocationService.isDeveloperMockEnabled, isFalse);
      expect(DeviceLocationService.mockPosition, isNull);
    });

    test('Enabling mock location sets explicit flag and allows manual testing', () {
      DeviceLocationService.setMockLocation(
        latitude: 22.4850,
        longitude: 73.5330,
      );

      expect(DeviceLocationService.isDeveloperMockEnabled, isTrue);
      expect(DeviceLocationService.mockPosition?.latitude, 22.4850);
      expect(DeviceLocationService.mockPosition?.longitude, 73.5330);

      DeviceLocationService.clearMockLocation();
      expect(DeviceLocationService.isDeveloperMockEnabled, isFalse);
      expect(DeviceLocationService.mockPosition, isNull);
    });
  });
}
