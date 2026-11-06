import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../models/spiritual_place.dart';
import '../services/directions_service.dart';
import '../services/offline_map_service.dart';
import '../services/spiritual_zone_service.dart';

class SpiritualPlaceDetailsScreen extends StatelessWidget {
  final SpiritualPlace place;
  final Position? userPosition;

  const SpiritualPlaceDetailsScreen({
    super.key,
    required this.place,
    this.userPosition,
  });

  @override
  Widget build(BuildContext context) {
    double? distance;
    SpiritualZone zone = SpiritualZone.outside;

    if (userPosition != null) {
      distance = SpiritualZoneService.calculateDistance(
        userPosition!.latitude,
        userPosition!.longitude,
        place.latitude,
        place.longitude,
      );
      zone = SpiritualZoneService.getZone(
        place,
        userPosition!.latitude,
        userPosition!.longitude,
      );
    }

    final double multiplier = SpiritualZoneService.getIntensityMultiplier(
      zone,
      place,
    );
    final String zoneName = SpiritualZoneService.getZoneName(zone);

    final isHigh = zone == SpiritualZone.highIntensity;
    final isLow = zone == SpiritualZone.lowIntensity;

    return Scaffold(
      appBar: AppBar(
        title: Text(place.name),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withValues(alpha: 0.15),
                    Colors.orange.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.temple_hindu_rounded,
                      size: 64,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      place.category,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.place_outlined,
                        size: 18,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          place.city.isNotEmpty && place.district.isNotEmpty
                              ? '${place.city}, ${place.district} (${place.region})'
                              : place.region,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    place.description,
                    style: const TextStyle(fontSize: 15, height: 1.45),
                  ),
                  const SizedBox(height: 20),

                  // Proximity and Zone Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isHigh
                            ? Colors.deepOrange.shade200
                            : isLow
                                ? Colors.amber.shade200
                                : Colors.grey.shade200,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Zone & Multiplier Status',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (distance != null) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Straight-Line Distance:'),
                                Text(
                                  '${(distance / 1000).toStringAsFixed(2)} km',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Current Classification:'),
                              Text(
                                zoneName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isHigh
                                      ? Colors.deepOrange.shade800
                                      : isLow
                                          ? Colors.amber.shade900
                                          : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Configured Multiplier:'),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${multiplier.toStringAsFixed(1)}x',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Zone Config:'),
                              Text(
                                'High: ${place.highMultiplier}x • Low: ${place.lowMultiplier}x',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Note: Multipliers are a configurable product visualization based on published boundaries.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade500,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Zone Map Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Published Zone Polygons',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!place.hasValidPolygons)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Boundary pending',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 240,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: LatLng(
                            place.latitude,
                            place.longitude,
                          ),
                          initialZoom: 14.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://mt{s}.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
                            subdomains: const ['0', '1', '2', '3'],
                            userAgentPackageName: 'com.mindspace.app',
                            tileProvider: OfflineCachingTileProvider(),
                          ),
                          PolygonLayer(
                            polygons: [
                              if (place.hasLowIntensityPolygon)
                                Polygon(
                                  points: place.lowIntensityPolygon,
                                  color: Colors.amber.withValues(alpha: 0.28),
                                  borderColor: Colors.orange.shade800,
                                  borderStrokeWidth: 2,
                                  isFilled: true,
                                ),
                              if (place.hasHighIntensityPolygon)
                                Polygon(
                                  points: place.highIntensityPolygon,
                                  color: Colors.deepOrange.withValues(
                                    alpha: 0.38,
                                  ),
                                  borderColor: Colors.red.shade900,
                                  borderStrokeWidth: 2.5,
                                  isFilled: true,
                                ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: LatLng(
                                  place.latitude,
                                  place.longitude,
                                ),
                                width: 44,
                                height: 44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.deepOrange.shade600,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.temple_hindu_rounded,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                              ),
                              if (userPosition != null &&
                                  distance != null &&
                                  distance < 10000)
                                Marker(
                                  point: LatLng(
                                    userPosition!.latitude,
                                    userPosition!.longitude,
                                  ),
                                  width: 36,
                                  height: 36,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blue.shade600,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.person_pin_circle,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (userPosition != null) {
                          DirectionsService.launchDirections(
                            userPosition!.latitude,
                            userPosition!.longitude,
                            place.latitude,
                            place.longitude,
                          );
                        } else {
                          DirectionsService.launchDirections(
                            place.latitude,
                            place.longitude,
                            place.latitude,
                            place.longitude,
                          );
                        }
                      },
                      icon: const Icon(Icons.directions_rounded),
                      label: const Text('Get Directions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Back to Interactive Map'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
