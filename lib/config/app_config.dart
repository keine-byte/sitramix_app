class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.sitram.cecar.cloud',
  );

  static const int defaultPage = 1;
  static const int defaultPageSize = 50;
  static const int maxPageSize = 100;
}
