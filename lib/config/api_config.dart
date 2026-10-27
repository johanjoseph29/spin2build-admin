class ApiConfig {
  /// Base URL of the Flask backend.
  /// For local development, default is http://127.0.0.1:5000.
  /// When running for the event, change this to the organizer's LAN IP,
  /// e.g. 'http://192.168.1.50:5000'
  static String baseUrl = 'http://127.0.0.1:5000';
}
