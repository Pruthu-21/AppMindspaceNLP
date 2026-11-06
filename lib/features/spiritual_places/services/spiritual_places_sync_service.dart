import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../services/app_storage.dart';
import '../../../services/auth_manager.dart';
import '../models/spiritual_place.dart';

/// Handles synchronization of spiritual places geometry and metadata with the Laravel API.
/// Preserves cached local data during network errors and offline sessions.
class SpiritualPlacesSyncService {
  static final SpiritualPlacesSyncService _instance =
      SpiritualPlacesSyncService._internal();
  factory SpiritualPlacesSyncService() => _instance;
  SpiritualPlacesSyncService._internal();

  static const String _storageKey = 'cached_spiritual_places_v2';
  static const String _lastSyncKey = 'spiritual_places_last_synced_at';
  static const String _defaultApiUrl =
      'https://mindspacenlp.com/api/spiritual-places';

  final ValueNotifier<List<SpiritualPlace>> placesNotifier =
      ValueNotifier<List<SpiritualPlace>>([]);
  final ValueNotifier<bool> isSyncingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isOfflineNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<DateTime?> lastSyncTimestampNotifier =
      ValueNotifier<DateTime?>(null);
  final ValueNotifier<String?> syncErrorNotifier = ValueNotifier<String?>(null);

  http.Client? _customClient;

  /// Visible for testing to inject mock http clients.
  @visibleForTesting
  void setMockClient(http.Client? client) {
    _customClient = client;
  }

  http.Client get _client => _customClient ?? http.Client();

  /// Loads cached places immediately and asynchronously attempts to synchronize with the API.
  Future<List<SpiritualPlace>> loadPlaces({bool forceRefresh = false}) async {
    // 1. Fast path: Read locally persisted cache (from previous website sync)
    final cached = await _loadFromStorage();
    if (cached.isNotEmpty) {
      placesNotifier.value = cached;
    } else {
      placesNotifier.value = [];
    }

    await _loadLastSyncTimestamp();

    // 2. Background sync with website API
    if (forceRefresh || lastSyncTimestampNotifier.value == null || cached.isEmpty) {
      await syncWithWebsite();
    }

    return placesNotifier.value;
  }

  static const String _customApiUrlKey = 'spiritual_places_custom_api_url';

  /// Returns configured custom API URL or the default endpoint.
  Future<String> getEffectiveApiUrl() async {
    final custom = await AppStorage.read(_customApiUrlKey);
    if (custom != null && custom.trim().isNotEmpty) {
      return custom.trim();
    }
    return _defaultApiUrl;
  }

  /// Sets or clears a custom API endpoint URL.
  Future<void> setCustomApiUrl(String? url) async {
    if (url == null || url.trim().isEmpty) {
      await AppStorage.delete(_customApiUrlKey);
    } else {
      await AppStorage.write(_customApiUrlKey, url.trim());
    }
  }

  /// Synchronizes places with Laravel API.
  /// Validates received geometry, updates local records, and preserves previous cache on failure.
  Future<bool> syncWithWebsite({String? apiUrl}) async {
    isSyncingNotifier.value = true;
    syncErrorNotifier.value = null;

    final targetUrl = apiUrl ?? await getEffectiveApiUrl();
    final headers = {
      'Accept': 'application/json',
      'User-Agent': 'MindspaceNLPApp/1.0',
      if (AuthManager.token != null)
        'Authorization': 'Bearer ${AuthManager.token}',
    };

    try {
      final response = await _client
          .get(Uri.parse(targetUrl), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> rawList = [];

        if (decoded is List) {
          rawList = decoded;
        } else if (decoded is Map) {
          if (decoded['data'] is List) {
            rawList = decoded['data'];
          } else if (decoded['places'] is List) {
            rawList = decoded['places'];
          } else if (decoded['items'] is List) {
            rawList = decoded['items'];
          }
        }

        final List<SpiritualPlace> validPlaces = [];
        for (final item in rawList) {
          if (item is Map<String, dynamic> || item is Map) {
            try {
              final place = SpiritualPlace.fromJson(
                Map<String, dynamic>.from(item),
              );

              // Validate reference coordinates
              if (place.latitude >= -90.0 &&
                  place.latitude <= 90.0 &&
                  place.longitude >= -180.0 &&
                  place.longitude <= 180.0 &&
                  place.name.trim().isNotEmpty &&
                  place.isPublished) {
                validPlaces.add(place);
              }
            } catch (e) {
              debugPrint('Error parsing spiritual place item: $e');
            }
          }
        }

        if (validPlaces.isNotEmpty) {
          // Successfully fetched and validated
          placesNotifier.value = validPlaces;
          isOfflineNotifier.value = false;
          final now = DateTime.now();
          lastSyncTimestampNotifier.value = now;

          await _saveToStorage(validPlaces);
          await AppStorage.write(_lastSyncKey, now.toIso8601String());

          isSyncingNotifier.value = false;
          return true;
        } else {
          syncErrorNotifier.value =
              'Endpoint reached but returned 0 published spiritual places.';
          isOfflineNotifier.value = false;
        }
      } else {
        String msg = 'Server returned HTTP ${response.statusCode}';
        try {
          final errBody = jsonDecode(response.body);
          if (errBody is Map && errBody['message'] != null) {
            msg = '${errBody['message']} (HTTP ${response.statusCode})';
          }
        } catch (_) {}
        syncErrorNotifier.value = msg;
        isOfflineNotifier.value = true;
      }
    } catch (e) {
      debugPrint('Spiritual places sync error (preserving cached data): $e');
      syncErrorNotifier.value = e.toString();
      isOfflineNotifier.value = true;
    } finally {
      isSyncingNotifier.value = false;
    }

    // Preserve previously valid local data
    final existing = await _loadFromStorage();
    if (existing.isNotEmpty) {
      placesNotifier.value = existing;
    }

    return false;
  }

  Future<List<SpiritualPlace>> _loadFromStorage() async {
    try {
      final jsonStr = await AppStorage.read(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is List) {
          final places = decoded
              .map((e) => SpiritualPlace.fromJson(Map<String, dynamic>.from(e)))
              .where((p) => p.isPublished)
              .toList();
          if (places.isNotEmpty) return places;
        }
      }
    } catch (e) {
      debugPrint('Error loading cached spiritual places: $e');
    }
    return [];
  }

  Future<void> _saveToStorage(List<SpiritualPlace> places) async {
    try {
      final jsonList = places.map((p) => p.toJson()).toList();
      await AppStorage.write(_storageKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error caching spiritual places: $e');
    }
  }

  Future<void> _loadLastSyncTimestamp() async {
    try {
      final timeStr = await AppStorage.read(_lastSyncKey);
      if (timeStr != null && timeStr.isNotEmpty) {
        lastSyncTimestampNotifier.value = DateTime.tryParse(timeStr);
      }
    } catch (_) {}
  }
}
