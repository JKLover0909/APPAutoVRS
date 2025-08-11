import 'package:flutter/foundation.dart';

class AuthProvider extends ChangeNotifier {
  bool _isWorkerAuthenticated = false;
  bool _isAdminAuthenticated = false;

  bool get isWorkerAuthenticated => _isWorkerAuthenticated;
  bool get isAdminAuthenticated => _isAdminAuthenticated;
  bool get hasAnyAuth => _isWorkerAuthenticated || _isAdminAuthenticated;

  Future<bool> authenticateWorker(String password) async {
    // Worker can use both 'worker' and 'admin' passwords
    if (password == 'worker' || password == 'admin') {
      _isWorkerAuthenticated = true;
      if (password == 'admin') {
        _isAdminAuthenticated = true;
      }
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> authenticateAdmin(String password) async {
    // Admin authentication requires 'admin' password
    if (password == 'admin') {
      _isAdminAuthenticated = true;
      _isWorkerAuthenticated = true; // Admin has worker privileges too
      notifyListeners();
      return true;
    }
    return false;
  }

  void logout() {
    _isWorkerAuthenticated = false;
    _isAdminAuthenticated = false;
    notifyListeners();
  }

  bool canAccessFeature(String requiredRole) {
    switch (requiredRole) {
      case 'worker':
        return _isWorkerAuthenticated;
      case 'admin':
        return _isAdminAuthenticated;
      default:
        return true; // No authentication required
    }
  }
}
