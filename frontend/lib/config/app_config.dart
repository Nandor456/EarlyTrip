class AppConfig {
  /// For Android emulator use `http://10.0.2.2:<port>`.
  /// For physical devices use your machine LAN IP.
  static const String serverBaseUrl = 'http://10.0.2.2:3000';

  static const String apiBaseUrl = '$serverBaseUrl/api';
  static const String socketPath = '/ws';

  /// Converts a relative path like `uploads/x.jpg` or `/uploads/x.jpg`
  /// into an absolute URL based on [serverBaseUrl].
  static String absoluteUrl(String urlOrPath) {
    if (urlOrPath.startsWith('http://') || urlOrPath.startsWith('https://')) {
      return urlOrPath;
    }

    final normalized = urlOrPath.startsWith('/')
        ? urlOrPath.substring(1)
        : urlOrPath;

    return '$serverBaseUrl/$normalized';
  }
}
