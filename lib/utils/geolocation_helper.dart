import 'geolocation_result.dart';
import 'geolocation_helper_stub.dart'
    if (dart.library.html) 'geolocation_helper_web.dart' as geo;

export 'geolocation_result.dart';

class GeolocationHelper {
  static Future<RealLocationResult> getCurrentLocation() async {
    return await geo.getRealCurrentLocation();
  }
}

