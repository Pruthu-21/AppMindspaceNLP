import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/spiritual_place.dart';
import '../utils/geojson_parser.dart';

enum SpiritualZone { highIntensity, lowIntensity, outside }

class SpiritualZoneService {
  /// Calculates straight-line distance (in meters) between two coordinates using WGS-84 ellipsoid.
  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }

  /// Determines whether the user coordinates fall inside the place's published polygon geometry.
  ///
  /// Classification rules:
  /// - Inside the high-intensity polygon: High Intensity Zone.
  /// - Outside high-intensity but inside low-intensity polygon: Low Intensity Zone.
  /// - Outside both polygons: Outside Spiritual Zones.
  ///
  /// Note: Polygon containment is independent of straight-line distance to the temple reference pin.
  static SpiritualZone getZone(
    SpiritualPlace place,
    double userLat,
    double userLon,
  ) {
    final userPoint = LatLng(userLat, userLon);

    // 1. Primary path: Evaluate exact published GeoJSON polygons
    if (place.hasHighIntensityPolygon &&
        GeoJsonPolygonParser.isPointInsidePolygon(
          userPoint,
          place.highIntensityPolygon,
        )) {
      return SpiritualZone.highIntensity;
    }

    if (place.hasLowIntensityPolygon &&
        GeoJsonPolygonParser.isPointInsidePolygon(
          userPoint,
          place.lowIntensityPolygon,
        )) {
      return SpiritualZone.lowIntensity;
    }

    // 2. Fallback path: If polygons are unavailable, check legacy radius boundaries
    if (!place.hasHighIntensityPolygon && !place.hasLowIntensityPolygon) {
      final distance = calculateDistance(
        userLat,
        userLon,
        place.latitude,
        place.longitude,
      );
      if (distance <= place.innerRadius) {
        return SpiritualZone.highIntensity;
      } else if (distance <= place.outerRadius) {
        return SpiritualZone.lowIntensity;
      }
    }

    return SpiritualZone.outside;
  }

  /// Finds the highest intensity zone among a collection of places for a given user coordinate.
  static ({SpiritualZone zone, SpiritualPlace? place}) getActiveZoneAcrossPlaces(
    List<SpiritualPlace> places,
    double userLat,
    double userLon,
  ) {
    SpiritualPlace? matchedPlace;
    SpiritualZone highestZone = SpiritualZone.outside;

    for (final place in places) {
      final zone = getZone(place, userLat, userLon);
      if (zone == SpiritualZone.highIntensity) {
        return (zone: SpiritualZone.highIntensity, place: place);
      } else if (zone == SpiritualZone.lowIntensity &&
          highestZone != SpiritualZone.highIntensity) {
        highestZone = SpiritualZone.lowIntensity;
        matchedPlace = place;
      }
    }

    return (zone: highestZone, place: matchedPlace);
  }

  /// Returns the configured multiplier value for the specified zone and place.
  static double getIntensityMultiplier(
    SpiritualZone zone, [
    SpiritualPlace? place,
  ]) {
    switch (zone) {
      case SpiritualZone.highIntensity:
        return place?.highMultiplier ?? 2.0;
      case SpiritualZone.lowIntensity:
        return place?.lowMultiplier ?? 1.5;
      case SpiritualZone.outside:
        return 1.0;
    }
  }

  static String getZoneName(SpiritualZone zone) {
    switch (zone) {
      case SpiritualZone.highIntensity:
        return 'High Intensity Zone';
      case SpiritualZone.lowIntensity:
        return 'Low Intensity Zone';
      case SpiritualZone.outside:
        return 'Outside Spiritual Zones';
    }
  }
}
