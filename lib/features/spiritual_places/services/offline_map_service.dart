import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

enum MapTileStatus {
  ok,
  restricted403,
  offline,
}

class OfflineDownloadState {
  final bool isDownloading;
  final int current;
  final int total;
  final double progress;
  final String message;
  final bool isSuccess;
  final String? error;

  const OfflineDownloadState({
    this.isDownloading = false,
    this.current = 0,
    this.total = 0,
    this.progress = 0.0,
    this.message = '',
    this.isSuccess = false,
    this.error,
  });

  factory OfflineDownloadState.idle() => const OfflineDownloadState();
}

/// Offline-first caching tile provider for flutter_map.
/// Checks the local disk first. If missing, attempts to download and cache.
/// When tile loading encounters 403 Access Blocked or network failure,
/// updates [OfflineMapService.tileStatusNotifier] and serves a transparent tile
/// to prevent unsightly red error boxes while keeping vector polygons fully functional.
class OfflineCachingTileProvider extends TileProvider {
  OfflineCachingTileProvider({
    super.headers,
    this.cacheSubdirectory = 'offline_maps',
  });

  final String cacheSubdirectory;
  Directory? _cacheDir;

  Future<Directory> _getCacheDir() async {
    if (_cacheDir != null) return _cacheDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/$cacheSubdirectory');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return OfflineCachingImageProvider(
      url: url,
      coordinates: coordinates,
      getCacheDir: _getCacheDir,
      headers: headers,
    );
  }
}

class OfflineCachingImageProvider
    extends ImageProvider<OfflineCachingImageProvider> {
  OfflineCachingImageProvider({
    required this.url,
    required this.coordinates,
    required this.getCacheDir,
    this.headers = const {},
  });

  final String url;
  final TileCoordinates coordinates;
  final Future<Directory> Function() getCacheDir;
  final Map<String, String> headers;

  static const String userAgent =
      'MindSpaceNLP-MobileApp/1.0.20 (+https://mindspacenlp.com; dev@mindspacenlp.com)';

  @override
  ImageStreamCompleter loadImage(
    OfflineCachingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<Codec> _load(
    OfflineCachingImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      final cacheDir = await getCacheDir();
      final tileFile = File(
        '${cacheDir.path}/${coordinates.z}/${coordinates.x}/${coordinates.y}.png',
      );

      // 1. Check local persistent disk cache
      if (await tileFile.exists()) {
        final bytes = await tileFile.readAsBytes();
        if (bytes.isNotEmpty) {
          final buffer = await ImmutableBuffer.fromUint8List(bytes);
          return await decode(buffer);
        }
      }

      // 2. Fetch from network with compliant headers
      final requestHeaders = Map<String, String>.from(headers);
      if (!requestHeaders.containsKey('User-Agent')) {
        requestHeaders['User-Agent'] = userAgent;
      }

      final response = await http
          .get(Uri.parse(url), headers: requestHeaders)
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        OfflineMapService.tileStatusNotifier.value = MapTileStatus.ok;

        // Cache to disk asynchronously
        tileFile.parent
            .create(recursive: true)
            .then((_) {
              tileFile.writeAsBytes(response.bodyBytes);
            })
            .catchError((_) {});

        final buffer = await ImmutableBuffer.fromUint8List(response.bodyBytes);
        return await decode(buffer);
      } else if (response.statusCode == 403) {
        // Diagnosed 403 Forbidden / Access Blocked by provider policy or network restriction
        OfflineMapService.tileStatusNotifier.value =
            MapTileStatus.restricted403;
      } else {
        OfflineMapService.tileStatusNotifier.value = MapTileStatus.offline;
      }
    } catch (_) {
      OfflineMapService.tileStatusNotifier.value = MapTileStatus.offline;
    }

    // Return transparent 1x1 image so flutter_map cleanly displays vector polygons
    final buffer = await ImmutableBuffer.fromUint8List(
      TileProvider.transparentImage,
    );
    return await decode(buffer);
  }

  @override
  SynchronousFuture<OfflineCachingImageProvider> obtainKey(
    ImageConfiguration configuration,
  ) {
    return SynchronousFuture<OfflineCachingImageProvider>(this);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OfflineCachingImageProvider &&
        other.url == url &&
        other.coordinates == coordinates;
  }

  @override
  int get hashCode => Object.hash(url, coordinates);
}

/// Service managing pre-downloaded offline tiles for Gujarat spiritual places.
class OfflineMapService {
  static final OfflineMapService _instance = OfflineMapService._internal();
  factory OfflineMapService() => _instance;
  OfflineMapService._internal();

  static final ValueNotifier<MapTileStatus> tileStatusNotifier =
      ValueNotifier<MapTileStatus>(MapTileStatus.ok);

  final ValueNotifier<OfflineDownloadState> downloadStateNotifier =
      ValueNotifier<OfflineDownloadState>(OfflineDownloadState.idle());

  bool _isCancelled = false;

  Future<Directory> getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/offline_maps');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Calculates slippy map tile coordinates
  static int lon2tileX(double lon, int z) {
    return ((lon + 180.0) / 360.0 * (1 << z)).floor();
  }

  static int lat2tileY(double lat, int z) {
    final rad = lat * pi / 180.0;
    return ((1.0 - log(tan(rad) + 1.0 / cos(rad)) / pi) / 2.0 * (1 << z))
        .floor();
  }

  /// Bounded Gujarat area covering Pavagadh, Ambaji, and Dwarka
  /// Lat: 21.8 - 24.6, Lon: 68.8 - 73.8, zoom levels: 7 to 10 (~270 tiles, ~4-5 MB)
  List<({int z, int x, int y})> getGujaratTileCoordinates() {
    final tiles = <({int z, int x, int y})>[];
    const double minLat = 21.8;
    const double maxLat = 24.6;
    const double minLon = 68.8;
    const double maxLon = 73.8;

    for (int z = 7; z <= 10; z++) {
      final xMin = lon2tileX(minLon, z);
      final xMax = lon2tileX(maxLon, z);
      final yMin = lat2tileY(maxLat, z);
      final yMax = lat2tileY(minLat, z);

      for (int x = xMin; x <= xMax; x++) {
        for (int y = yMin; y <= yMax; y++) {
          tiles.add((z: z, x: x, y: y));
        }
      }
    }
    return tiles;
  }

  void cancelDownload() {
    _isCancelled = true;
  }

  Future<void> downloadGujaratRegion() async {
    _isCancelled = false;
    final allTiles = getGujaratTileCoordinates();
    final total = allTiles.length;
    final cacheDir = await getCacheDirectory();

    downloadStateNotifier.value = OfflineDownloadState(
      isDownloading: true,
      current: 0,
      total: total,
      progress: 0.0,
      message: 'Preparing download of $total tiles...',
    );

    int downloaded = 0;
    int alreadyCached = 0;

    for (int i = 0; i < total; i++) {
      if (_isCancelled) {
        downloadStateNotifier.value = OfflineDownloadState(
          isDownloading: false,
          current: downloaded + alreadyCached,
          total: total,
          progress: (downloaded + alreadyCached) / total,
          message: 'Download cancelled.',
        );
        return;
      }

      final tile = allTiles[i];
      final file = File('${cacheDir.path}/${tile.z}/${tile.x}/${tile.y}.png');

      if (await file.exists() && (await file.length()) > 0) {
        alreadyCached++;
      } else {
        try {
          final url =
              'https://tile.openstreetmap.org/${tile.z}/${tile.x}/${tile.y}.png';
          final response = await http
              .get(
                Uri.parse(url),
                headers: {
                  'User-Agent': OfflineCachingImageProvider.userAgent,
                },
              )
              .timeout(const Duration(seconds: 5));

          if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
            await file.parent.create(recursive: true);
            await file.writeAsBytes(response.bodyBytes);
            downloaded++;
          } else if (response.statusCode == 403) {
            tileStatusNotifier.value = MapTileStatus.restricted403;
          }
          await Future.delayed(const Duration(milliseconds: 30));
        } catch (e) {
          debugPrint(
            'Error downloading tile ${tile.z}/${tile.x}/${tile.y}: $e',
          );
        }
      }

      final processed = downloaded + alreadyCached;
      downloadStateNotifier.value = OfflineDownloadState(
        isDownloading: true,
        current: processed,
        total: total,
        progress: processed / total,
        message: 'Downloading offline Gujarat tiles ($processed / $total)...',
      );
    }

    downloadStateNotifier.value = OfflineDownloadState(
      isDownloading: false,
      current: total,
      total: total,
      progress: 1.0,
      isSuccess: true,
      message:
          'Downloaded $downloaded new tiles ($alreadyCached cached). Ready offline!',
    );
  }

  Future<int> getCachedTileCount() async {
    try {
      final cacheDir = await getCacheDirectory();
      if (!await cacheDir.exists()) return 0;
      int count = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File && entity.path.endsWith('.png')) {
          count++;
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<String> getCacheSizeFormatted() async {
    try {
      final cacheDir = await getCacheDirectory();
      if (!await cacheDir.exists()) return '0 KB';
      int bytes = 0;
      await for (final entity in cacheDir.list(recursive: true)) {
        if (entity is File) {
          bytes += await entity.length();
        }
      }
      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '0 KB';
    }
  }

  Future<void> clearCache() async {
    try {
      final cacheDir = await getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
      downloadStateNotifier.value = OfflineDownloadState.idle();
    } catch (e) {
      debugPrint('Error clearing offline map cache: $e');
    }
  }
}
