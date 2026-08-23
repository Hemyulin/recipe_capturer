class AppConfig {
  const AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'COOKBUK_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3000',
  );

  static const apiBaseUrlList = String.fromEnvironment('COOKBUK_API_BASE_URLS');

  static List<String> get apiBaseUrls {
    final values = apiBaseUrlList
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (values.isNotEmpty) return values;
    return [apiBaseUrl];
  }

  static const sharedToken = String.fromEnvironment('COOKBUK_SHARED_TOKEN');
}
