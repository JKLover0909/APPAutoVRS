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

class AppRoutes {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const MainLayout(child: HomeScreen()),
      ),
      GoRoute(
        path: '/select-model',
        name: 'select_model',
        builder: (context, state) =>
            const MainLayout(child: SelectModelScreen()),
      ),
      GoRoute(
        path: '/add-model',
        name: 'add_model',
        builder: (context, state) => const MainLayout(child: AddModelScreen()),
      ),
      GoRoute(
        path: '/vrs-main',
        name: 'vrs_main',
        builder: (context, state) => const MainLayout(child: VRSMainScreen()),
      ),
      GoRoute(
        path: '/manual-vrs',
        name: 'manual_vrs',
        builder: (context, state) => const MainLayout(child: ManualVRSScreen()),
      ),
      GoRoute(
        path: '/light-adjust',
        name: 'light_adjust',
        builder: (context, state) =>
            const MainLayout(child: LightAdjustScreen()),
      ),
      GoRoute(
        path: '/board-align/:step',
        name: 'board_align',
        builder: (context, state) {
          final step = int.tryParse(state.pathParameters['step'] ?? '1') ?? 1;
          return MainLayout(child: BoardAlignScreen(step: step));
        },
      ),
      GoRoute(
        path: '/statistics',
        name: 'statistics',
        builder: (context, state) =>
            const MainLayout(child: StatisticsScreen()),
      ),
      GoRoute(
        path: '/ng-rate',
        name: 'ng_rate',
        builder: (context, state) => const MainLayout(child: NGRateScreen()),
      ),
      GoRoute(
        path: '/select-lot',
        name: 'select_lot',
        builder: (context, state) => const MainLayout(child: SelectLotScreen()),
      ),
      GoRoute(
        path: '/defect-type',
        name: 'defect_type',
        builder: (context, state) =>
            const MainLayout(child: DefectTypeScreen()),
      ),
    ],
  );
}
