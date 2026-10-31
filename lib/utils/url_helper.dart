import 'url_helper_stub.dart'
    if (dart.library.html) 'url_helper_web.dart' as uh;

class UrlHelper {
  static void openUrl(String url) {
    uh.openExternalUrl(url);
  }
}

