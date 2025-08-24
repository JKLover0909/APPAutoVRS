import 'package:flutter/foundation.dart';

class AppLog {
  // Toggle this to enable/disable prints app-wide
  static bool enabled = false;

  static void d(String msg) {
    if (enabled) debugPrint(msg);
  }
}
