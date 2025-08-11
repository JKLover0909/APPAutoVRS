import 'package:flutter/foundation.dart';

class NavigationProvider extends ChangeNotifier {
  final List<String> _viewHistory = ['home'];
  String _currentView = 'home';

  String get currentView => _currentView;
  List<String> get viewHistory => List.unmodifiable(_viewHistory);
  bool get canGoBack => _viewHistory.length > 1;

  void navigateTo(String viewId, {bool addToHistory = true}) {
    if (addToHistory && (viewHistory.isEmpty || viewHistory.last != viewId)) {
      _viewHistory.add(viewId);
    }
    _currentView = viewId;
    notifyListeners();
  }

  void goBack() {
    if (canGoBack) {
      _viewHistory.removeLast();
      _currentView = _viewHistory.last;
      notifyListeners();
    }
  }

  void clearHistory() {
    _viewHistory.clear();
    _viewHistory.add('home');
    _currentView = 'home';
    notifyListeners();
  }

  // View titles mapping
  String getViewTitle(String viewId) {
    const viewTitles = {
      'home': 'Trang chủ',
      'select_model': 'Cài đặt Model',
      'add_model': 'Cài đặt > Thêm mã hàng mới',
      'vrs_main': 'Giám sát Auto VRS',
      'statistics': 'Thống kê',
      'ng_rate': 'Thống kê > Tỉ lệ phán định',
      'select_lot': 'Thống kê > Chọn lô hàng',
      'defect_type': 'Thống kê > Chi tiết loại lỗi',
      'manual_vrs': 'VRS Thủ công',
      'light_adjust': 'VRS Thủ công > Điều chỉnh ánh sáng',
      'board_align_1': 'Định vị > Bước 1/4',
      'board_align_2': 'Định vị > Bước 2/4',
      'board_align_3': 'Định vị > Bước 3/4',
      'board_align_4': 'Định vị > Bước 4/4',
    };
    return viewTitles[viewId] ?? 'AutoVRS';
  }
}
