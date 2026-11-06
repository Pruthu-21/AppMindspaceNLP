import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/spiritual_place.dart';
import '../services/device_location_service.dart';
import '../services/directions_service.dart';
import '../services/offline_map_service.dart';
import '../services/spiritual_places_sync_service.dart';
import '../services/spiritual_zone_service.dart';
import '../widgets/intensity_zone_legend.dart';
import '../widgets/selected_place_panel.dart';
import '../widgets/spiritual_place_card.dart';
import 'nearby_places_screen.dart';

class SpiritualPlacesMapScreen extends StatefulWidget {
  const SpiritualPlacesMapScreen({super.key});

  @override
  State<SpiritualPlacesMapScreen> createState() =>
      _SpiritualPlacesMapScreenState();
}

class _SpiritualPlacesMapScreenState extends State<SpiritualPlacesMapScreen>
    with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final DeviceLocationService _locationService = DeviceLocationService();
  final OfflineMapService _offlineMapService = OfflineMapService();
  final SpiritualPlacesSyncService _syncService = SpiritualPlacesSyncService();
  late final OfflineCachingTileProvider _offlineTileProvider =
      OfflineCachingTileProvider();

  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  Position? _currentPosition;
  bool _isLoadingLocation = true;
  LocationPrerequisiteStatus _prerequisiteStatus =
      LocationPrerequisiteStatus.ready;
  bool _hasRequestedInitialPermission = false;

  SpiritualPlace? _selectedPlace;
  List<SpiritualPlace> _places = [];
  bool _hasCenteredOnInitialPosition = false;
  bool _isSatelliteMap = true;

  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _syncService.placesNotifier.addListener(_onPlacesUpdated);
    _places = _syncService.placesNotifier.value;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDataAndLocation(isInitial: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncService.placesNotifier.removeListener(_onPlacesUpdated);
    _positionStreamSubscription?.cancel();
    _sheetController.dispose();
    super.dispose();
  }

  void _onPlacesUpdated() {
    if (mounted) {
      setState(() {
        _places = _syncService.placesNotifier.value;
        // Keep selected place synchronized if its geometry updated
        if (_selectedPlace != null) {
          final updated = _places.firstWhere(
            (p) => p.id == _selectedPlace!.id,
            orElse: () => _selectedPlace!,
          );
          _selectedPlace = updated;
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAndInitLocation(isInitial: false);
    }
  }

  Future<void> _initDataAndLocation({bool isInitial = false}) async {
    // 1. Load cached places immediately
    await _syncService.loadPlaces(forceRefresh: false);
    // 2. Obtain device location
    await _checkAndInitLocation(isInitial: isInitial);
  }

  Future<void> _checkAndInitLocation({bool isInitial = false}) async {
    setState(() {
      _isLoadingLocation = true;
    });

    var status = await _locationService.checkPrerequisites();

    if (status == LocationPrerequisiteStatus.permissionDenied &&
        isInitial &&
        !_hasRequestedInitialPermission) {
      _hasRequestedInitialPermission = true;
      if (mounted) {
        await _locationService.requestPermissionWithUI(context);
        status = await _locationService.checkPrerequisites();
      }
    }

    if (!mounted) return;

    if (status != LocationPrerequisiteStatus.ready) {
      setState(() {
        _isLoadingLocation = false;
        _prerequisiteStatus = status;
        _currentPosition = null;
      });
      return;
    }

    final position = await _locationService.getCurrentPosition();

    if (mounted) {
      setState(() {
        _isLoadingLocation = false;
        _prerequisiteStatus = LocationPrerequisiteStatus.ready;
        if (position != null) {
          _currentPosition = position;
          if (!_hasCenteredOnInitialPosition) {
            _hasCenteredOnInitialPosition = true;
            _mapController.move(
              LatLng(position.latitude, position.longitude),
              12.0,
            );
          }
        } else if (!_hasCenteredOnInitialPosition) {
          _hasCenteredOnInitialPosition = true;
          // Gujarat Center default if GPS timed out
          _mapController.move(const LatLng(23.0225, 72.5714), 7.5);
        }
      });
    }

    _startLocationUpdates();
  }

  void _startLocationUpdates() {
    _positionStreamSubscription?.cancel();
    if (DeviceLocationService.isDeveloperMockEnabled) return;

    try {
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      ).listen(
        (Position newPos) {
          if (mounted) {
            setState(() {
              _currentPosition = newPos;
              // Do NOT reset camera to user location on every GPS tick if user has selected a place
            });
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
  }

  void _onPlaceTapped(SpiritualPlace place) {
    setState(() {
      _selectedPlace = place;
    });

    // Move camera to place coordinates without unnecessary resets
    _mapController.move(LatLng(place.latitude, place.longitude), 14.5);

    // Smoothly expand sheet slightly to reveal selected place card
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.42,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1.0);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1.0);
  }

  void _recenterUser() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        14.0,
      );
    } else {
      _checkAndInitLocation();
    }
  }

  void _showOfflineMapsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return FutureBuilder<List<dynamic>>(
              future: Future.wait([
                _offlineMapService.getCachedTileCount(),
                _offlineMapService.getCacheSizeFormatted(),
              ]),
              builder: (context, snapshot) {
                final tileCount = (snapshot.data?[0] as int?) ?? 0;
                final cacheSize = (snapshot.data?[1] as String?) ?? '0 KB';

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.cloud_download,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Gujarat Offline Map Support',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Cache map tiles covering Gujarat pilgrimage sites (Pavagadh, Ambaji, Dwarka, Somnath) across zoom levels 7–10 (~270 bounded tiles) for reliable offline access.',
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  'Cached Tiles',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$tileCount',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              height: 30,
                              width: 1,
                              color: Colors.grey.shade300,
                            ),
                            Column(
                              children: [
                                const Text(
                                  'Storage Used',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  cacheSize,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ValueListenableBuilder<OfflineDownloadState>(
                        valueListenable:
                            _offlineMapService.downloadStateNotifier,
                        builder: (context, state, _) {
                          if (state.isDownloading) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: state.progress > 0
                                      ? state.progress
                                      : null,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        state.message,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    Text(
                                      '${(state.progress * 100).toInt()}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    _offlineMapService.cancelDownload();
                                  },
                                  icon: const Icon(Icons.cancel, size: 16),
                                  label: const Text('Cancel Download'),
                                ),
                              ],
                            );
                          }

                          if (state.isSuccess) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      state.message,
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          return Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    await _offlineMapService
                                        .downloadGujaratRegion();
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(Icons.download),
                                  label: const Text('Download Gujarat Region'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).primaryColor,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              if (tileCount > 0) ...[
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: () async {
                                    await _offlineMapService.clearCache();
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Clear',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showApiSettingsDialog() async {
    final currentUrl = await _syncService.getEffectiveApiUrl();
    if (!mounted) return;
    final textController = TextEditingController(text: currentUrl);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final lastError = _syncService.syncErrorNotifier.value;
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.api_rounded, color: Colors.deepPurple),
                  SizedBox(width: 8),
                  Text(
                    'API Endpoint & Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Website API URL for Spiritual Places:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: textController,
                      decoration: InputDecoration(
                        hintText: 'https://mindspacenlp.com/api/spiritual-places',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (lastError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 16,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lastError,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red.shade900,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'If returning 404, please add to Laravel routes/api.php:\n'
                      'Route::get(\'/spiritual-places\', [SpiritualPlaceController::class, \'index\']);\n\n'
                      'And clear route cache on Hostinger with `php artisan route:clear`.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    textController.text =
                        'https://mindspacenlp.com/api/spiritual-places';
                    await _syncService.setCustomApiUrl(null);
                    setDialogState(() {});
                  },
                  child: const Text('Reset Default'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newUrl = textController.text.trim();
                    await _syncService.setCustomApiUrl(newUrl);
                    if (mounted) Navigator.of(ctx).pop();
                    final ok = await _syncService.syncWithWebsite();
                    if (mounted) {
                      final errMsg = _syncService.syncErrorNotifier.value;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Polygons synchronized from website!'
                                : (errMsg ?? 'Sync failed'),
                          ),
                          backgroundColor:
                              ok ? Colors.green.shade800 : Colors.red.shade800,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  },
                  child: const Text('Save & Sync'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTopStatusHeader() {
    // Current zone calculation
    SpiritualZone activeZone = SpiritualZone.outside;
    SpiritualPlace? activePlace = _selectedPlace;
    double? activeMultiplier;

    if (_currentPosition != null) {
      if (_selectedPlace != null) {
        activeZone = SpiritualZoneService.getZone(
          _selectedPlace!,
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        activeMultiplier = SpiritualZoneService.getIntensityMultiplier(
          activeZone,
          _selectedPlace,
        );
      } else {
        final res = SpiritualZoneService.getActiveZoneAcrossPlaces(
          _places,
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        activeZone = res.zone;
        activePlace = res.place;
        if (activePlace != null) {
          activeMultiplier = SpiritualZoneService.getIntensityMultiplier(
            activeZone,
            activePlace,
          );
        }
      }
    }

    String zoneStatusText;
    Color zoneColor;
    IconData zoneIcon;

    if (_isLoadingLocation) {
      zoneStatusText = 'Finding nearby spiritual places...';
      zoneColor = Colors.blue.shade700;
      zoneIcon = Icons.location_searching_rounded;
    } else if (_prerequisiteStatus != LocationPrerequisiteStatus.ready) {
      zoneStatusText = 'Location unavailable';
      zoneColor = Colors.orange.shade800;
      zoneIcon = Icons.location_disabled_rounded;
    } else {
      switch (activeZone) {
        case SpiritualZone.highIntensity:
          zoneStatusText =
              'High Intensity Zone (${activeMultiplier?.toStringAsFixed(1) ?? '2.0'}x)';
          zoneColor = Colors.deepOrange.shade800;
          zoneIcon = Icons.local_fire_department_rounded;
          break;
        case SpiritualZone.lowIntensity:
          zoneStatusText =
              'Low Intensity Zone (${activeMultiplier?.toStringAsFixed(1) ?? '1.5'}x)';
          zoneColor = Colors.amber.shade900;
          zoneIcon = Icons.wb_sunny_rounded;
          break;
        case SpiritualZone.outside:
          zoneStatusText = 'Outside Spiritual Zones';
          zoneColor = Colors.grey.shade700;
          zoneIcon = Icons.navigation_rounded;
          break;
      }
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // Back Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Title and Status Indicators
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedPlace != null
                          ? _selectedPlace!.name
                          : 'Spiritual Places & Zones',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(zoneIcon, size: 14, color: zoneColor),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            zoneStatusText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: zoneColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions: Sync, Offline Maps, Dev Mock
              ValueListenableBuilder<bool>(
                valueListenable: _syncService.isSyncingNotifier,
                builder: (context, isSyncing, _) {
                  return IconButton(
                    icon: isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_rounded, size: 20),
                    tooltip: 'Sync with website',
                    onPressed: isSyncing
                        ? null
                        : () async {
                            final ok = await _syncService.syncWithWebsite();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ok
                                        ? 'Polygons synchronized from website!'
                                        : 'Offline mode: using cached polygons.',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                  );
                },
              ),

              IconButton(
                icon: const Icon(Icons.cloud_download_outlined, size: 20),
                tooltip: 'Offline Maps',
                onPressed: () => _showOfflineMapsSheet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTileStatusBanner() {
    return ValueListenableBuilder<MapTileStatus>(
      valueListenable: OfflineMapService.tileStatusNotifier,
      builder: (context, status, _) {
        if (status == MapTileStatus.ok) return const SizedBox.shrink();

        final is403 = status == MapTileStatus.restricted403;
        final message = is403
            ? 'Map tiles restricted (403 Policy) • Polygons active offline'
            : 'Offline map mode • Vector polygons active';

        return Positioned(
          top: 76,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.layers_clear_outlined,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _showOfflineMapsSheet(context),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      'Tiles',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrerequisiteBlockingCard() {
    IconData icon;
    String title;
    String description;
    String buttonText;
    VoidCallback onAction;

    switch (_prerequisiteStatus) {
      case LocationPrerequisiteStatus.permissionDenied:
        icon = Icons.location_disabled;
        title = 'Location Permission Required';
        description =
            'MindSpaceNLP requires location access to discover nearby spiritual places and calculate spiritual intensity zones relative to your real position.';
        buttonText = 'Grant Location Permission';
        onAction = () async {
          await _locationService.requestPermissionWithUI(context);
          _checkAndInitLocation();
        };
        break;

      case LocationPrerequisiteStatus.permissionDeniedForever:
        icon = Icons.lock_clock;
        title = 'Location Permission Permanently Denied';
        description =
            'Location permission was permanently denied. Please open system settings and enable Location permissions for MindSpaceNLP.';
        buttonText = 'Open App Settings';
        onAction = () async {
          await _locationService.openAppSettings();
        };
        break;

      case LocationPrerequisiteStatus.gpsDisabled:
        icon = Icons.gps_off;
        title = 'Device GPS / Location Is Turned Off';
        description =
            'Device location services are currently disabled. Please turn on GPS to view your position and calculate spiritual zones.';
        buttonText = 'Turn On GPS / Location Settings';
        onAction = () async {
          await _locationService.openLocationSettings();
        };
        break;

      case LocationPrerequisiteStatus.ready:
        return const SizedBox.shrink();
    }

    return Positioned(
      top: 80,
      left: 16,
      right: 16,
      child: Card(
        elevation: 6,
        color: Colors.amber.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.amber.shade400, width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.orange.shade800, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.brown.shade800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _checkAndInitLocation(),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Recheck'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepOrange.shade600,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(buttonText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the polygons directly from published website geometry.
  List<Polygon> _buildPolygons() {
    final List<Polygon> list = [];

    for (final place in _places) {
      // 1. Low Intensity Outer Polygon (Translucent amber)
      if (place.hasLowIntensityPolygon) {
        list.add(
          Polygon(
            points: place.lowIntensityPolygon,
            color: Colors.amber.withValues(alpha: 0.28),
            borderColor: Colors.orange.shade800,
            borderStrokeWidth: 2.0,
            isFilled: true,
          ),
        );
      }

      // 2. High Intensity Inner Polygon (Translucent saffron/red)
      if (place.hasHighIntensityPolygon) {
        list.add(
          Polygon(
            points: place.highIntensityPolygon,
            color: Colors.deepOrange.withValues(alpha: 0.38),
            borderColor: Colors.red.shade900,
            borderStrokeWidth: 2.5,
            isFilled: true,
          ),
        );
      }
    }

    return list;
  }

  /// Builds place markers and user location marker.
  List<Marker> _buildMarkers(bool isPrerequisiteBlocked) {
    final List<Marker> markers = [];

    // Spiritual Place Markers
    for (final place in _places) {
      final isSelected = _selectedPlace?.id == place.id;
      markers.add(
        Marker(
          point: LatLng(place.latitude, place.longitude),
          width: isSelected ? 56 : 44,
          height: isSelected ? 56 : 44,
          child: GestureDetector(
            onTap: () => _onPlaceTapped(place),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? Colors.deepPurple.shade700
                    : Colors.deepOrange.shade600,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.temple_hindu_rounded,
                  color: Colors.white,
                  size: isSelected ? 30 : 22,
                ),
              ),
            ),
          ),
        ),
      );
    }

    // User Location Marker
    if (_currentPosition != null && !isPrerequisiteBlocked) {
      markers.add(
        Marker(
          point: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          width: 48,
          height: 48,
          child: Tooltip(
            message: 'Your Location',
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withValues(alpha: 0.25),
                  ),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.shade600,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildDraggableBottomPanel() {
    // Sort places by straight-line distance from user position
    final sortedPlaces = List<SpiritualPlace>.from(_places);
    if (_currentPosition != null) {
      sortedPlaces.sort((a, b) {
        final distA = SpiritualZoneService.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a.latitude,
          a.longitude,
        );
        final distB = SpiritualZoneService.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });
    }

    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: _selectedPlace != null ? 0.40 : 0.32,
      minChildSize: 0.18,
      maxChildSize: 0.88,
      snap: true,
      snapSizes: const [0.18, 0.38, 0.88],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Drag Handle
              SliverToBoxAdapter(
                child: Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(top: 10, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),

              // Selected Place Panel (if a place is active)
              if (_selectedPlace != null) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: SelectedPlacePanel(
                      place: _selectedPlace!,
                      userPosition: _currentPosition,
                      onClose: () {
                        setState(() {
                          _selectedPlace = null;
                        });
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Divider(height: 1, indent: 16, endIndent: 16),
                ),
              ],

              // Nearby Places Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.temple_hindu_rounded,
                            size: 18,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Published Spiritual Places (${sortedPlaces.length})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NearbyPlacesScreen(),
                            ),
                          );
                        },
                        child: const Text('View All'),
                      ),
                    ],
                  ),
                ),
              ),

              // Places List
              if (sortedPlaces.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 24.0,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.temple_hindu_outlined,
                            size: 44,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No Published Places Loaded',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Connect to the internet and sync with mindspacenlp.com to download live places and geofence polygons.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.3,
                            ),
                          ),
                          ValueListenableBuilder<String?>(
                            valueListenable: _syncService.syncErrorNotifier,
                            builder: (context, error, _) {
                              if (error == null) return const SizedBox.shrink();
                              return Container(
                                margin: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 16,
                                      color: Colors.red.shade700,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        error,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade900,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          ValueListenableBuilder<bool>(
                            valueListenable: _syncService.isSyncingNotifier,
                            builder: (context, isSyncing, _) {
                              return Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: isSyncing
                                        ? null
                                        : () async {
                                            final ok = await _syncService
                                                .syncWithWebsite();
                                            if (context.mounted) {
                                              final errMsg = _syncService
                                                  .syncErrorNotifier
                                                  .value;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    ok
                                                        ? 'Places synchronized from website!'
                                                        : (errMsg ??
                                                            'Sync failed'),
                                                  ),
                                                  backgroundColor: ok
                                                      ? Colors.green.shade800
                                                      : Colors.red.shade800,
                                                  duration: const Duration(
                                                    seconds: 4,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    icon: isSyncing
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.sync, size: 16),
                                    label: Text(
                                      isSyncing
                                          ? 'Syncing...'
                                          : 'Sync From Website',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: _showApiSettingsDialog,
                                    icon: const Icon(
                                      Icons.settings_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('API Setup'),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final place = sortedPlaces[index];
                        return SpiritualPlaceCard(
                          place: place,
                          userPosition: _currentPosition,
                          onViewOnMap: () => _onPlaceTapped(place),
                        );
                      },
                      childCount: sortedPlaces.length,
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 28),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPrerequisiteBlocked =
        _prerequisiteStatus != LocationPrerequisiteStatus.ready;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Interactive FlutterMap with Dynamic Polygons
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(23.0225, 72.5714), // Gujarat Center
              initialZoom: 7.5,
              onTap: (tapPosition, point) {
                if (_selectedPlace != null) {
                  setState(() {
                    _selectedPlace = null;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatelliteMap
                    ? 'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: _isSatelliteMap
                    ? const ['0', '1', '2', '3']
                    : const ['a', 'b', 'c'],
                userAgentPackageName: 'com.mindspace.app',
                tileProvider: _offlineTileProvider,
              ),

              // Dynamic Low & High Intensity Polygons from Website API
              PolygonLayer(polygons: _buildPolygons()),

              // Published Temple Markers & Real User Location
              MarkerLayer(markers: _buildMarkers(isPrerequisiteBlocked)),

              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    _isSatelliteMap
                        ? 'Satellite © Google Hybrid'
                        : 'OpenStreetMap contributors',
                  ),
                ],
              ),
            ],
          ),

          // 2. Map Error / 403 Status Banner
          _buildTileStatusBanner(),

          // 3. Top Floating Status Header
          _buildTopStatusHeader(),

          // 4. Prerequisite Blocking Warning (Location disabled / denied)
          if (isPrerequisiteBlocked && !_isLoadingLocation)
            _buildPrerequisiteBlockingCard(),

          // 5. Floating Legend
          if (!isPrerequisiteBlocked)
            const Positioned(top: 86, right: 14, child: IntensityZoneLegend()),

          // 6. Map Zoom Controls & Recenter Button
          Positioned(
            right: 14,
            bottom: MediaQuery.of(context).size.height * 0.42,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Satellite / Street Map Style Toggle
                Material(
                  color: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isSatelliteMap = !_isSatelliteMap;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Tooltip(
                        message: _isSatelliteMap
                            ? 'Switch to Street Map'
                            : 'Switch to Satellite Map',
                        child: Icon(
                          _isSatelliteMap
                              ? Icons.satellite_alt_rounded
                              : Icons.map_outlined,
                          size: 20,
                          color: _isSatelliteMap
                              ? Colors.deepPurple.shade700
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Material(
                  color: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    onTap: _zoomIn,
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(Icons.add, size: 22, color: Colors.black87),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Material(
                  color: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    onTap: _zoomOut,
                    borderRadius: BorderRadius.circular(10),
                    child: const SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.remove,
                        size: 22,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: 'recenter_gps_fab',
                  onPressed: _recenterUser,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // 7. Draggable Bottom Information Panel
          _buildDraggableBottomPanel(),

          // 8. Location Loading Indicator
          if (_isLoadingLocation)
            Center(
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(width: 16),
                      Text('Locating spiritual zones...'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
