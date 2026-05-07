import 'package:go_router/go_router.dart';
import '../screens/main_layout.dart';
import '../screens/home_screen.dart';
import '../screens/model_management/select_model_screen.dart';
import '../screens/model_management/add_model_screen.dart';
import '../screens/vrs/vrs_main_screen.dart';
import '../screens/vrs/manual_vrs_screen.dart';
import '../screens/vrs/light_adjust_screen.dart';
import '../screens/alignment/board_align_screen.dart';
import '../screens/statistics/statistics_screen.dart';
import '../screens/statistics/ng_rate_screen.dart';
import '../screens/statistics/select_lot_screen.dart';
import '../screens/statistics/defect_type_screen.dart';
import '../screens/camera_screen.dart';

class AppRoutePaths {
  static const String home = '/';
  static const String selectModel = '/select-model';
  static const String addModel = '/add-model';
  static const String vrsMain = '/vrs-main';
  static const String manualVrs = '/manual-vrs';
  static const String lightAdjust = '/light-adjust';
  static const String boardAlign = '/board-align/:step';
  static const String statistics = '/statistics';
  static const String ngRate = '/ng-rate';
  static const String selectLot = '/select-lot';
  static const String defectType = '/defect-type';
  static const String camera = '/camera';
}

class AppRoutes {
  static final GoRouter router = GoRouter(
    initialLocation: AppRoutePaths.home,
    routes: [
      GoRoute(
        path: AppRoutePaths.home,
        name: 'home',
        builder: (context, state) => const MainLayout(child: HomeScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.selectModel,
        name: 'select_model',
        builder: (context, state) =>
            const MainLayout(child: SelectModelScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.addModel,
        name: 'add_model',
        builder: (context, state) => const MainLayout(child: AddModelScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.vrsMain,
        name: 'vrs_main',
        builder: (context, state) => const MainLayout(child: VRSMainScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.manualVrs,
        name: 'manual_vrs',
        builder: (context, state) => const MainLayout(child: ManualVRSScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.lightAdjust,
        name: 'light_adjust',
        builder: (context, state) =>
            const MainLayout(child: LightAdjustScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.boardAlign,
        name: 'board_align',
        builder: (context, state) {
          final step = int.tryParse(state.pathParameters['step'] ?? '1') ?? 1;
          return MainLayout(child: BoardAlignScreen(step: step));
        },
      ),
      GoRoute(
        path: AppRoutePaths.statistics,
        name: 'statistics',
        builder: (context, state) =>
            const MainLayout(child: StatisticsScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.ngRate,
        name: 'ng_rate',
        builder: (context, state) => const MainLayout(child: NGRateScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.selectLot,
        name: 'select_lot',
        builder: (context, state) => const MainLayout(child: SelectLotScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.defectType,
        name: 'defect_type',
        builder: (context, state) =>
            const MainLayout(child: DefectTypeScreen()),
      ),
      GoRoute(
        path: AppRoutePaths.camera,
        name: 'camera',
        builder: (context, state) => const CameraScreen(),
      ),
    ],
  );
}
