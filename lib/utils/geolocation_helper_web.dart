// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:http/http.dart' as http;
import 'geolocation_result.dart';

Future<RealLocationResult> getRealCurrentLocation() async {
  final geo = html.window.navigator.geolocation;

  // Request browser geolocation permission and get position
  final html.Geoposition pos = await geo.getCurrentPosition(
    enableHighAccuracy: true,
    timeout: const Duration(seconds: 15),
    maximumAge: const Duration(seconds: 0),
  );

  final lat = pos.coords?.latitude?.toDouble() ?? 0.0;
  final lng = pos.coords?.longitude?.toDouble() ?? 0.0;

  if (lat == 0.0 && lng == 0.0) {
    throw Exception('Không tìm thấy toạ độ GPS hợp lệ.');
  }

  // Reverse geocode via OpenStreetMap Nominatim
  String locationName = 'Vị trí hiện tại (GPS)';
  String address = 'Toạ độ: ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';

  try {
    final uri = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=jsonv2&lat=$lat&lon=$lng&accept-language=vi',
    );
    final response = await http.get(uri, headers: {
      'User-Agent': 'SupaChat/1.0 (supachat-web)',
    }).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final displayName = data['display_name'] as String?;
      final addrMap = data['address'] as Map<String, dynamic>?;

      if (addrMap != null) {
        final road = addrMap['road'] ?? addrMap['pedestrian'] ?? addrMap['suburb'] ?? addrMap['quarter'];
        final city = addrMap['city'] ?? addrMap['state'] ?? addrMap['county'] ?? addrMap['town'];
        if (road != null && city != null) {
          locationName = '$road, $city';
        } else if (road != null) {
          locationName = road.toString();
        } else if (city != null) {
          locationName = city.toString();
        }
      }

      if (displayName != null && displayName.isNotEmpty) {
        address = displayName;
      }
    }
  } catch (_) {
    // If reverse geocoding fails or times out, keep coordinates format
  }

  return RealLocationResult(
    latitude: lat,
    longitude: lng,
    locationName: locationName,
    address: address,
  );
}
