import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../utils/geojson_parser.dart';

/// Represents a spiritual destination with reference coordinates, metadata,
/// and dynamic Low & High intensity zone polygons managed through the website API.
class SpiritualPlace {
  final String id;
  final String name;
  final String region;
  final String city;
  final String district;
  final double latitude;
  final double longitude;
  final String category;
  final String description;
  final double highMultiplier;
  final double lowMultiplier;
  final bool isPublished;
  final String? version;
  final DateTime? updatedAt;

  /// Parsed polygon boundary vertices for the High Intensity zone
  final List<LatLng> highIntensityPolygon;

  /// Parsed polygon boundary vertices for the Low Intensity zone
  final List<LatLng> lowIntensityPolygon;

  /// Raw GeoJSON geometry structures from API
  final Map<String, dynamic>? highIntensityGeoJson;
  final Map<String, dynamic>? lowIntensityGeoJson;

  /// Fallback circle radii (meters) for backwards compatibility
  final double innerRadius;
  final double outerRadius;

  const SpiritualPlace({
    required this.id,
    required this.name,
    required this.region,
    this.city = '',
    this.district = '',
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.description,
    this.highMultiplier = 2.0,
    this.lowMultiplier = 1.5,
    this.isPublished = true,
    this.version,
    this.updatedAt,
    this.highIntensityPolygon = const [],
    this.lowIntensityPolygon = const [],
    this.highIntensityGeoJson,
    this.lowIntensityGeoJson,
    this.innerRadius = 200.0,
    this.outerRadius = 1000.0,
  });

  bool get hasHighIntensityPolygon => highIntensityPolygon.length >= 3;
  bool get hasLowIntensityPolygon => lowIntensityPolygon.length >= 3;
  bool get hasValidPolygons => hasHighIntensityPolygon && hasLowIntensityPolygon;

  /// Factory constructor to parse spiritual place records from Laravel API or local cache.
  factory SpiritualPlace.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] ?? '').toString();
    final String name = (json['name'] ?? json['title'] ?? '').toString();
    final String region = (json['region'] ?? json['location'] ?? '').toString();
    final String city = (json['city'] ?? '').toString();
    final String district = (json['district'] ?? '').toString();

    final rawLat = json['latitude'] ?? json['lat'];
    final double lat = rawLat is num
        ? rawLat.toDouble()
        : double.tryParse(rawLat?.toString() ?? '0') ?? 0.0;

    final rawLng = json['longitude'] ?? json['lng'] ?? json['lon'];
    final double lng = rawLng is num
        ? rawLng.toDouble()
        : double.tryParse(rawLng?.toString() ?? '0') ?? 0.0;

    final String category = (json['category'] ?? 'Spiritual Place').toString();
    final String description = (json['description'] ?? '').toString();

    final rawHigh = json['high_multiplier'] ?? json['highMultiplier'];
    final double highMult = rawHigh is num
        ? rawHigh.toDouble()
        : double.tryParse(rawHigh?.toString() ?? '2.0') ?? 2.0;

    final rawLow = json['low_multiplier'] ?? json['lowMultiplier'];
    final double lowMult = rawLow is num
        ? rawLow.toDouble()
        : double.tryParse(rawLow?.toString() ?? '1.5') ?? 1.5;

    final bool published = json['is_published'] == null ||
        json['is_published'] == true ||
        json['is_published'] == 1 ||
        json['is_published'] == '1' ||
        json['status'] == 'published';

    final String? ver = json['version']?.toString();

    DateTime? updated;
    if (json['updated_at'] != null) {
      updated = DateTime.tryParse(json['updated_at'].toString());
    }

    // Parse High Intensity polygon GeoJSON
    final dynamic rawHighPoly = json['high_intensity_polygon'] ??
        json['highIntensityPolygon'] ??
        json['high_polygon'];
    final highPoints = GeoJsonPolygonParser.parsePolygonCoordinates(rawHighPoly);
    Map<String, dynamic>? highGeoJson;
    if (rawHighPoly is Map) {
      highGeoJson = Map<String, dynamic>.from(rawHighPoly);
    } else if (rawHighPoly is String && rawHighPoly.trim().startsWith('{')) {
      try {
        highGeoJson = Map<String, dynamic>.from(jsonDecode(rawHighPoly));
      } catch (_) {}
    }

    // Parse Low Intensity polygon GeoJSON
    final dynamic rawLowPoly = json['low_intensity_polygon'] ??
        json['lowIntensityPolygon'] ??
        json['low_polygon'];
    final lowPoints = GeoJsonPolygonParser.parsePolygonCoordinates(rawLowPoly);
    Map<String, dynamic>? lowGeoJson;
    if (rawLowPoly is Map) {
      lowGeoJson = Map<String, dynamic>.from(rawLowPoly);
    } else if (rawLowPoly is String && rawLowPoly.trim().startsWith('{')) {
      try {
        lowGeoJson = Map<String, dynamic>.from(jsonDecode(rawLowPoly));
      } catch (_) {}
    }

    final rawInner = json['inner_radius'] ?? json['innerRadius'];
    final double innerRad = rawInner is num
        ? rawInner.toDouble()
        : double.tryParse(rawInner?.toString() ?? '200') ?? 200.0;

    final rawOuter = json['outer_radius'] ?? json['outerRadius'];
    final double outerRad = rawOuter is num
        ? rawOuter.toDouble()
        : double.tryParse(rawOuter?.toString() ?? '1000') ?? 1000.0;

    return SpiritualPlace(
      id: id,
      name: name,
      region: region,
      city: city,
      district: district,
      latitude: lat,
      longitude: lng,
      category: category,
      description: description,
      highMultiplier: highMult,
      lowMultiplier: lowMult,
      isPublished: published,
      version: ver,
      updatedAt: updated,
      highIntensityPolygon: highPoints,
      lowIntensityPolygon: lowPoints,
      highIntensityGeoJson: highGeoJson,
      lowIntensityGeoJson: lowGeoJson,
      innerRadius: innerRad,
      outerRadius: outerRad,
    );
  }

  /// Serializes place data to Map for local storage cache.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'region': region,
      'city': city,
      'district': district,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'description': description,
      'high_multiplier': highMultiplier,
      'low_multiplier': lowMultiplier,
      'is_published': isPublished,
      'version': version,
      'updated_at': updatedAt?.toIso8601String(),
      'high_intensity_polygon': highIntensityGeoJson ??
          GeoJsonPolygonParser.toGeoJsonPolygon(highIntensityPolygon),
      'low_intensity_polygon': lowIntensityGeoJson ??
          GeoJsonPolygonParser.toGeoJsonPolygon(lowIntensityPolygon),
      'inner_radius': innerRadius,
      'outer_radius': outerRadius,
    };
  }

  SpiritualPlace copyWith({
    String? id,
    String? name,
    String? region,
    String? city,
    String? district,
    double? latitude,
    double? longitude,
    String? category,
    String? description,
    double? highMultiplier,
    double? lowMultiplier,
    bool? isPublished,
    String? version,
    DateTime? updatedAt,
    List<LatLng>? highIntensityPolygon,
    List<LatLng>? lowIntensityPolygon,
    Map<String, dynamic>? highIntensityGeoJson,
    Map<String, dynamic>? lowIntensityGeoJson,
    double? innerRadius,
    double? outerRadius,
  }) {
    return SpiritualPlace(
      id: id ?? this.id,
      name: name ?? this.name,
      region: region ?? this.region,
      city: city ?? this.city,
      district: district ?? this.district,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      description: description ?? this.description,
      highMultiplier: highMultiplier ?? this.highMultiplier,
      lowMultiplier: lowMultiplier ?? this.lowMultiplier,
      isPublished: isPublished ?? this.isPublished,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      highIntensityPolygon: highIntensityPolygon ?? this.highIntensityPolygon,
      lowIntensityPolygon: lowIntensityPolygon ?? this.lowIntensityPolygon,
      highIntensityGeoJson: highIntensityGeoJson ?? this.highIntensityGeoJson,
      lowIntensityGeoJson: lowIntensityGeoJson ?? this.lowIntensityGeoJson,
      innerRadius: innerRadius ?? this.innerRadius,
      outerRadius: outerRadius ?? this.outerRadius,
    );
  }
}
