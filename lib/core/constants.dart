class AppConstants {
  // API Configuration
  static const String baseUrl = 'http://localhost:3000';
  static const String apiUrl = '$baseUrl/api';
  static const String socketUrl = baseUrl;
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String themeKey = 'theme_mode';
  
  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
