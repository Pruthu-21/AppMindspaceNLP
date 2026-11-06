import 'dart:convert';
import 'package:latlong2/latlong.dart';

/// Utility for parsing GeoJSON polygon geometry and evaluating
/// ray-casting point-in-polygon containment with boundary edge detection.
class GeoJsonPolygonParser {
  /// Parses GeoJSON polygon or multipolygon into a list of [LatLng] vertices.
  ///
  /// Supports:
  /// - GeoJSON Polygon: `{"type": "Polygon", "coordinates": [[[lon, lat], ...]]}`
  /// - GeoJSON MultiPolygon: `{"type": "MultiPolygon", "coordinates": [[[[lon, lat], ...]]]}`
  /// - GeoJSON Feature / Geometry map
  /// - Raw coordinate arrays: `[[[lon, lat], ...]]` or `[[lon, lat], ...]`
  /// - JSON string representation of any of the above
  ///
  /// GeoJSON coordinates RFC 7946 specify: `[longitude, latitude]`.
  /// This parser properly converts `coord[0]` (lon) and `coord[1]` (lat) to `LatLng(lat, lon)`.
  static List<LatLng> parsePolygonCoordinates(dynamic rawData) {
    if (rawData == null) return const [];

    dynamic data = rawData;
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return const [];
      try {
        data = jsonDecode(trimmed);
      } catch (_) {
        return const [];
      }
    }

    if (data is Map<String, dynamic> || data is Map) {
      final map = Map<String, dynamic>.from(data);
      // If it is a Feature, extract geometry
      if (map['type'] == 'Feature' && map['geometry'] is Map) {
        return parsePolygonCoordinates(map['geometry']);
      }
      final type = map['type']?.toString().toLowerCase();
      final coordinates = map['coordinates'];

      if (coordinates is List) {
        if (type == 'polygon') {
          return _parsePolygonRings(coordinates);
        } else if (type == 'multipolygon') {
          return _parseMultiPolygon(coordinates);
        } else {
          // Attempt generic coordinate parse
          return _parsePolygonRings(coordinates);
        }
      }
    }

    if (data is List) {
      return _parsePolygonRings(data);
    }

    return const [];
  }

  /// Parses Polygon coordinate rings: outer ring is coordinates[0].
  static List<LatLng> _parsePolygonRings(List dynamicList) {
    if (dynamicList.isEmpty) return const [];

    // Case 1: List of rings [[[lon, lat], ...], ...]
    if (dynamicList.first is List) {
      final firstChild = dynamicList.first as List;
      // If first child is also a list of coords: [[lon, lat], ...]
      if (firstChild.isNotEmpty && firstChild.first is List) {
        final List<LatLng> points = [];
        for (final item in firstChild) {
          final pt = _parseSinglePoint(item);
          if (pt != null) points.add(pt);
        }
        return points;
      }

      // Case 2: List of coordinate points directly: [[lon, lat], [lon, lat], ...]
      final List<LatLng> points = [];
      for (final item in dynamicList) {
        final pt = _parseSinglePoint(item);
        if (pt != null) points.add(pt);
      }
      return points;
    }

    return const [];
  }

  /// Parses MultiPolygon coordinate rings: uses the first polygon's outer ring
  static List<LatLng> _parseMultiPolygon(List dynamicList) {
    if (dynamicList.isEmpty) return const [];
    final firstPoly = dynamicList.first;
    if (firstPoly is List) {
      return _parsePolygonRings(firstPoly);
    }
    return const [];
  }

  /// Converts GeoJSON `[longitude, latitude]` to `LatLng(latitude, longitude)`
  static LatLng? _parseSinglePoint(dynamic point) {
    if (point is! List || point.length < 2) return null;
    final num? lon = num.tryParse(point[0].toString());
    final num? lat = num.tryParse(point[1].toString());
    if (lon == null || lat == null) return null;

    final double latVal = lat.toDouble();
    final double lonVal = lon.toDouble();

    // Range validity check
    if (latVal < -90.0 || latVal > 90.0 || lonVal < -180.0 || lonVal > 180.0) {
      return null;
    }

    return LatLng(latVal, lonVal);
  }

  /// Converts a list of [LatLng] back to a standard GeoJSON Polygon Map.
  static Map<String, dynamic> toGeoJsonPolygon(List<LatLng> points) {
    if (points.isEmpty) {
      return {
        'type': 'Polygon',
        'coordinates': <List<List<double>>>[],
      };
    }

    final coordinates = points
        .map((p) => [p.longitude, p.latitude])
        .toList();

    // GeoJSON linear rings must close by repeating the first coordinate
    if (coordinates.isNotEmpty) {
      final first = coordinates.first;
      final last = coordinates.last;
      if (first[0] != last[0] || first[1] != last[1]) {
        coordinates.add([first[0], first[1]]);
      }
    }

    return {
      'type': 'Polygon',
      'coordinates': [coordinates],
    };
  }

  /// Evaluates whether [point] is inside or on the boundary of [polygon]
  /// using the Ray-Casting algorithm with boundary tolerance.
  static bool isPointInsidePolygon(LatLng point, List<LatLng> polygon) {
    if (polygon.length < 3) return false;

    // 1. Boundary check: If the point is on any edge or vertex, it is inside
    if (isPointOnPolygonBoundary(point, polygon)) {
      return true;
    }

    // 2. Ray-Casting Algorithm
    bool inside = false;
    final double x = point.longitude;
    final double y = point.latitude;
    final int n = polygon.length;

    for (int i = 0, j = n - 1; i < n; j = i++) {
      final double xi = polygon[i].longitude;
      final double yi = polygon[i].latitude;
      final double xj = polygon[j].longitude;
      final double yj = polygon[j].latitude;

      final bool intersect = ((yi > y) != (yj > y)) &&
          (x < (xj - xi) * (y - yi) / (yj - yi) + xi);

      if (intersect) {
        inside = !inside;
      }
    }

    return inside;
  }

  /// Checks if [point] lies on any polygon vertex or edge within [tolerance].
  static bool isPointOnPolygonBoundary(
    LatLng point,
    List<LatLng> polygon, {
    double tolerance = 1e-6,
  }) {
    final int n = polygon.length;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      if (_isPointOnSegment(point, polygon[j], polygon[i], tolerance)) {
        return true;
      }
    }
    return false;
  }

  /// Checks if [p] lies on the line segment between [a] and [b].
  static bool _isPointOnSegment(
    LatLng p,
    LatLng a,
    LatLng b,
    double tolerance,
  ) {
    // Check bounding box first
    final minX = a.longitude < b.longitude ? a.longitude : b.longitude;
    final maxX = a.longitude > b.longitude ? a.longitude : b.longitude;
    final minY = a.latitude < b.latitude ? a.latitude : b.latitude;
    final maxY = a.latitude > b.latitude ? a.latitude : b.latitude;

    if (p.longitude < minX - tolerance ||
        p.longitude > maxX + tolerance ||
        p.latitude < minY - tolerance ||
        p.latitude > maxY + tolerance) {
      return false;
    }

    // Cross product to measure collinearity
    final crossProduct = (p.latitude - a.latitude) * (b.longitude - a.longitude) -
        (p.longitude - a.longitude) * (b.latitude - a.latitude);

    if (crossProduct.abs() > tolerance) {
      return false;
    }

    // Dot product to check if between a and b
    final dotProduct = (p.longitude - a.longitude) * (b.longitude - a.longitude) +
        (p.latitude - a.latitude) * (b.latitude - a.latitude);
    if (dotProduct < -tolerance) return false;

    final squaredLength = (b.longitude - a.longitude) * (b.longitude - a.longitude) +
        (b.latitude - a.latitude) * (b.latitude - a.latitude);
    if (dotProduct > squaredLength + tolerance) return false;

    return true;
  }
}
