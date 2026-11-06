import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/spiritual_place.dart';
import '../services/directions_service.dart';
import '../services/spiritual_zone_service.dart';
import '../screens/spiritual_place_details_screen.dart';

class SelectedPlacePanel extends StatelessWidget {
  final SpiritualPlace place;
  final Position? userPosition;
  final VoidCallback onClose;

  const SelectedPlacePanel({
    super.key,
    required this.place,
    this.userPosition,
    required this.onClose,
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

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHigh
              ? Colors.deepOrange.shade300
              : isLow
                  ? Colors.amber.shade300
                  : Colors.grey.shade300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row with Title and Close
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            place.region,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Close place details',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Zone & Multipliers Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isHigh
                  ? Colors.deepOrange.shade50
                  : isLow
                      ? Colors.amber.shade50
                      : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHigh
                    ? Colors.deepOrange.shade200
                    : isLow
                        ? Colors.amber.shade200
                        : Colors.grey.shade200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isHigh
                          ? Icons.local_fire_department_rounded
                          : isLow
                              ? Icons.wb_sunny_rounded
                              : Icons.navigation_rounded,
                      size: 20,
                      color: isHigh
                          ? Colors.deepOrange.shade800
                          : isLow
                              ? Colors.amber.shade800
                              : Colors.grey.shade700,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          zoneName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isHigh
                                ? Colors.deepOrange.shade900
                                : isLow
                                    ? Colors.amber.shade900
                                    : Colors.grey.shade800,
                          ),
                        ),
                        Text(
                          'Multiplier: ${multiplier.toStringAsFixed(1)}x (High: ${place.highMultiplier}x, Low: ${place.lowMultiplier}x)',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (distance != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
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
          ),
          const SizedBox(height: 10),

          // Straight-line distance explanation
          if (distance != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Straight-line distance to temple center: ${(distance / 1000).toStringAsFixed(2)} km',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),

          if (place.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                place.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, height: 1.3),
              ),
            ),

          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SpiritualPlaceDetailsScreen(
                          place: place,
                          userPosition: userPosition,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
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
                      // Open destination directly in maps
                      DirectionsService.launchDirections(
                        place.latitude,
                        place.longitude,
                        place.latitude,
                        place.longitude,
                      );
                    }
                  },
                  icon: const Icon(Icons.directions, size: 18),
                  label: const Text('Get Directions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
