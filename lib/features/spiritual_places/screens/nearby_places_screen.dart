import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/spiritual_place.dart';
import '../services/device_location_service.dart';
import '../services/spiritual_places_sync_service.dart';
import '../services/spiritual_zone_service.dart';
import '../widgets/spiritual_place_card.dart';

class NearbyPlacesScreen extends StatefulWidget {
  const NearbyPlacesScreen({super.key});

  @override
  State<NearbyPlacesScreen> createState() => _NearbyPlacesScreenState();
}

class _NearbyPlacesScreenState extends State<NearbyPlacesScreen>
    with WidgetsBindingObserver {
  final DeviceLocationService _locationService = DeviceLocationService();
  final SpiritualPlacesSyncService _syncService = SpiritualPlacesSyncService();

  Position? _currentPosition;
  bool _isLoading = true;
  LocationPrerequisiteStatus _prerequisiteStatus =
      LocationPrerequisiteStatus.ready;
  String _selectedFilter = 'All Places';
  List<SpiritualPlace> _places = [];

  final List<String> _filters = [
    'All Places',
    'Nearby',
    'High Intensity Zone',
    'Low Intensity Zone',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncService.placesNotifier.addListener(_onPlacesUpdated);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncService.placesNotifier.removeListener(_onPlacesUpdated);
    super.dispose();
  }

  void _onPlacesUpdated() {
    if (mounted) {
      _sortAndSetPlaces(_syncService.placesNotifier.value);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // 1. Load cached or synchronized places
    final loaded = await _syncService.loadPlaces();

    // 2. Check location prerequisites
    final status = await _locationService.checkPrerequisites();
    if (status != LocationPrerequisiteStatus.ready) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _prerequisiteStatus = status;
          _currentPosition = null;
          _places = List.from(loaded);
        });
      }
      return;
    }

    final position = await _locationService.getCurrentPosition();

    if (mounted) {
      _currentPosition = position;
      _prerequisiteStatus = LocationPrerequisiteStatus.ready;
      _isLoading = false;
      _sortAndSetPlaces(loaded);
    }
  }

  void _sortAndSetPlaces(List<SpiritualPlace> raw) {
    final list = List<SpiritualPlace>.from(raw);
    if (_currentPosition != null) {
      list.sort((a, b) {
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
    setState(() {
      _places = list;
    });
  }

  List<SpiritualPlace> _getFilteredPlaces() {
    if (_currentPosition == null) return _places;

    return _places.where((place) {
      final zone = SpiritualZoneService.getZone(
        place,
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (_selectedFilter == 'All Places') return true;
      if (_selectedFilter == 'Nearby') {
        final dist = SpiritualZoneService.calculateDistance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          place.latitude,
          place.longitude,
        );
        return dist < 50000; // Within 50km
      }
      if (_selectedFilter == 'High Intensity Zone') {
        return zone == SpiritualZone.highIntensity;
      }
      if (_selectedFilter == 'Low Intensity Zone') {
        return zone == SpiritualZone.lowIntensity;
      }

      return true;
    }).toList();
  }

  Widget _buildBlockingBanner() {
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
            'Permission is needed to determine real distances and spiritual intensity multipliers.';
        buttonText = 'Grant Permission';
        onAction = () async {
          await _locationService.requestPermissionWithUI(context);
          _loadData();
        };
        break;

      case LocationPrerequisiteStatus.permissionDeniedForever:
        icon = Icons.lock_clock;
        title = 'Permission Permanently Denied';
        description =
            'Please enable location in system settings to calculate your distance to temples.';
        buttonText = 'Settings';
        onAction = () async {
          await _locationService.openAppSettings();
        };
        break;

      case LocationPrerequisiteStatus.gpsDisabled:
        icon = Icons.gps_off;
        title = 'Device GPS Is Turned Off';
        description =
            'Turn on location services on your device to display distance-sorted destinations.';
        buttonText = 'Turn On GPS';
        onAction = () async {
          await _locationService.openLocationSettings();
        };
        break;

      case LocationPrerequisiteStatus.ready:
        return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.orange.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text(buttonText, style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlaces = _getFilteredPlaces();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Spiritual Places'),
        actions: [
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
                    : const Icon(Icons.sync_rounded),
                tooltip: 'Sync places',
                onPressed: isSyncing
                    ? null
                    : () async {
                        final ok = await _syncService.syncWithWebsite();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                ok
                                    ? 'Synchronized with website!'
                                    : 'Using cached places offline.',
                              ),
                            ),
                          );
                        }
                      },
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _syncService.syncWithWebsite();
          await _loadData();
        },
        child: Column(
          children: [
            if (_prerequisiteStatus != LocationPrerequisiteStatus.ready)
              _buildBlockingBanner(),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            // Main List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredPlaces.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 8),
                              const Text('No spiritual places match the filter.'),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredPlaces.length,
                          itemBuilder: (context, index) {
                            final place = filteredPlaces[index];
                            return SpiritualPlaceCard(
                              place: place,
                              userPosition: _currentPosition,
                              onViewOnMap: () {
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
