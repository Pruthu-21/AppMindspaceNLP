import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/spiritual_place.dart';
import '../services/directions_service.dart';
import '../services/spiritual_zone_service.dart';

class SpiritualPlaceCard extends StatelessWidget {
  final SpiritualPlace place;
  final Position? userPosition;
  final VoidCallback onViewOnMap;

  const SpiritualPlaceCard({
    super.key,
    required this.place,
    this.userPosition,
    required this.onViewOnMap,
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

    final String zoneName = SpiritualZoneService.getZoneName(zone);
    final double multiplier = SpiritualZoneService.getIntensityMultiplier(
      zone,
      place,
    );
    final isHigh = zone == SpiritualZone.highIntensity;
    final isLow = zone == SpiritualZone.lowIntensity;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isHigh
              ? Colors.deepOrange.shade300
              : isLow
                  ? Colors.amber.shade300
                  : Colors.grey.shade200,
          width: isHigh || isLow ? 1.5 : 1.0,
        ),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isHigh
                        ? Colors.deepOrange.shade100
                        : isLow
                            ? Colors.amber.shade100
                            : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.temple_hindu_rounded,
                    color: isHigh
                        ? Colors.deepOrange.shade800
                        : Colors.orange.shade800,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        place.city.isNotEmpty && place.district.isNotEmpty
                            ? '${place.city}, ${place.district}'
                            : place.region,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${(distance / 1000).toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Metadata & Zone Chips
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (isHigh || isLow)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isHigh
                          ? Colors.deepOrange.shade50
                          : Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isHigh
                            ? Colors.deepOrange.shade200
                            : Colors.amber.shade200,
                      ),
                    ),
                    child: Text(
                      '$zoneName (${multiplier.toStringAsFixed(1)}x)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isHigh
                            ? Colors.deepOrange.shade900
                            : Colors.amber.shade900,
                      ),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    place.category,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (distance != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      '(straight-line)',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: Colors.grey.shade200),
            const SizedBox(height: 4),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onViewOnMap,
                  icon: const Icon(Icons.map_rounded, size: 16),
                  label: const Text('View on Map'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                const SizedBox(width: 4),
                TextButton.icon(
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
                  icon: const Icon(Icons.directions_rounded, size: 16),
                  label: const Text('Directions'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
