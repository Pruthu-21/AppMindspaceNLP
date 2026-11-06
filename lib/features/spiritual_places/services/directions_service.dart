import 'package:url_launcher/url_launcher.dart';

class DirectionsService {
  static Future<void> launchDirections(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    // Attempt Google Maps intent first
    final String googleMapsUrl =
        'https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLng&destination=$endLat,$endLng&travelmode=driving';

    final Uri url = Uri.parse(googleMapsUrl);

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      // Fallback or error handling
      throw 'Could not launch directions.';
    }
  }
}
