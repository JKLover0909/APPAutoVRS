import 'package:flutter/foundation.dart';

class ApiService extends ChangeNotifier {
  static const String _defaultBaseUrl = 'http://localhost:8000';
  
  String _baseUrl = _defaultBaseUrl;
  bool _isConnected = false;
  
  String get baseUrl => _baseUrl;
  bool get isConnected => _isConnected;
  
  void updateBaseUrl(String newBaseUrl) {
    _baseUrl = newBaseUrl;
    notifyListeners();
  }
  
  void setConnectionStatus(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }
  
  // Test connection to the backend
  Future<bool> testConnection() async {
    try {
      // Add connection test logic here
      setConnectionStatus(true);
      return true;
    } catch (e) {
      setConnectionStatus(false);
      return false;
    }
  }
}
