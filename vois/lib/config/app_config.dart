class AppConfig {
  static const serverUrl = String.fromEnvironment(
    'ECHO_SERVER_URL',
    defaultValue: 'http://192.168.1.216:8080',
  );
}
