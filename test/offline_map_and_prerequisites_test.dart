import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:mindspace_nlp/features/spiritual_places/services/offline_map_service.dart';
import 'package:mindspace_nlp/features/spiritual_places/services/device_location_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineMapService Tests', () {
    final offlineMapService = OfflineMapService();

    test('getGujaratTileCoordinates generates strictly bounded tile list', () {
      final tiles = offlineMapService.getGujaratTileCoordinates();

      expect(tiles.isNotEmpty, isTrue);
      // Ensure zoom levels range from 7 to 10
      final zoomLevels = tiles.map((t) => t.z).toSet();
      expect(zoomLevels, containsAll([7, 8, 9, 10]));
      expect(zoomLevels.length, 4);

      // Verify bounded count conforms to OSM policy (~200 to ~300 tiles)
      expect(tiles.length, greaterThan(200));
      expect(tiles.length, lessThan(350));
    });

    test(
      'lon2tileX and lat2tileY convert geographic coordinates correctly',
      () {
        // Test center of Gujarat (~23.0° N, ~72.5° E) at zoom 7
        final x = OfflineMapService.lon2tileX(72.5, 7);
        final y = OfflineMapService.lat2tileY(23.0, 7);

        expect(x, greaterThanOrEqualTo(85));
        expect(x, lessThanOrEqualTo(95));
        expect(y, greaterThanOrEqualTo(50));
        expect(y, lessThanOrEqualTo(60));
      },
    );

    test('OfflineDownloadState holds progress data correctly', () {
      const state = OfflineDownloadState(
        isDownloading: true,
        current: 138,
        total: 276,
        progress: 0.5,
        message: 'Downloading tiles (138 / 276)...',
        isSuccess: false,
      );

      expect(state.isDownloading, isTrue);
      expect(state.current, 138);
      expect(state.total, 276);
      expect(state.progress, 0.5);
      expect(state.isSuccess, isFalse);
    });

    test('TileProvider transparentImage is a valid 1x1 PNG byte array', () {
      final img = TileProvider.transparentImage;
      expect(img.isNotEmpty, isTrue);
      // Standard PNG magic signature: 0x89 0x50 0x4E 0x47 (PNG)
      expect(img[0], 0x89);
      expect(img[1], 0x50); // 'P'
      expect(img[2], 0x4E); // 'N'
      expect(img[3], 0x47); // 'G'
    });
  });

  group('DeviceLocationService Prerequisite Tests', () {
    final locationService = DeviceLocationService();

    tearDown(() {
      DeviceLocationService.clearMockLocation();
    });

    test('Mock location bypasses hardware checks and returns ready', () async {
      DeviceLocationService.setMockLocation(
        latitude: 22.4850,
        longitude: 73.5330,
      );

      expect(DeviceLocationService.isDeveloperMockEnabled, isTrue);
      final status = await locationService.checkPrerequisites();
      expect(status, LocationPrerequisiteStatus.ready);

      final position = await locationService.getCurrentPosition();
      expect(position, isNotNull);
      expect(position!.latitude, 22.4850);
      expect(position.longitude, 73.5330);
    });

    test('Clearing mock location restores real GPS mode', () async {
      DeviceLocationService.setMockLocation(
        latitude: 24.3310,
        longitude: 72.8480,
      );
      expect(DeviceLocationService.isDeveloperMockEnabled, isTrue);

      DeviceLocationService.clearMockLocation();
      expect(DeviceLocationService.isDeveloperMockEnabled, isFalse);
      expect(DeviceLocationService.mockPosition, isNull);
    });
  });
}
