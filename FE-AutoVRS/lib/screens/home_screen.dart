import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import '../providers/vrs_provider.dart';
import '../providers/auth_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          _buildWelcomeSection(context),

          const SizedBox(height: 24),

          // System Status Cards
          _buildSystemStatusCards(context),

          const SizedBox(height: 24),

          // Quick Actions
          _buildQuickActions(context),

          const SizedBox(height: 24),

          // Recent Activity
          _buildRecentActivity(context),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return Card(
          elevation: 2,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      FeatherIcons.monitor,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Chào mừng đến với AutoVRS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            authProvider.hasAnyAuth
                                ? 'Hệ thống kiểm tra tự động - ${authProvider.isAdminAuthenticated ? 'Admin' : 'Worker'}'
                                : 'Hệ thống kiểm tra tự động - Chưa đăng nhập',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (!authProvider.hasAnyAuth) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '⚠️ Vui lòng đăng nhập để sử dụng đầy đủ chức năng của hệ thống',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSystemStatusCards(BuildContext context) {
    return Consumer<VRSProvider>(
      builder: (context, vrsProvider, _) {
        return Row(
          children: [
            Expanded(
              child: _buildStatusCard(
                context,
                'Trạng thái hệ thống',
                vrsProvider.systemStatus,
                vrsProvider.systemStatus == 'OK' ? Colors.green : Colors.red,
                FeatherIcons.activity,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatusCard(
                context,
                'Chế độ hoạt động',
                vrsProvider.isAutoMode ? 'Auto' : 'Manual',
                vrsProvider.isAutoMode ? Colors.blue : Colors.orange,
                vrsProvider.isAutoMode ? FeatherIcons.play : FeatherIcons.edit,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatusCard(
                context,
                'Model hiện tại',
                vrsProvider.currentModel.isEmpty
                    ? 'Chưa chọn'
                    : vrsProvider.currentModel,
                vrsProvider.currentModel.isEmpty ? Colors.grey : Colors.green,
                FeatherIcons.package,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final actions = _getQuickActions(authProvider);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thao tác nhanh',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: actions
                  .map((action) => _buildActionCard(context, action))
                  .toList(),
            ),
          ],
        );
      },
    );
  }

  List<QuickAction> _getQuickActions(AuthProvider authProvider) {
    return [
      QuickAction(
        title: 'Cài đặt Model',
        icon: FeatherIcons.settings,
        route: '/select-model',
        color: Colors.blue,
        enabled: authProvider.canAccessFeature('admin'),
      ),
      QuickAction(
        title: 'Auto VRS',
        icon: FeatherIcons.monitor,
        route: '/vrs-main',
        color: Colors.green,
        enabled: authProvider.canAccessFeature('worker'),
      ),
      QuickAction(
        title: 'VRS Thủ công',
        icon: FeatherIcons.eye,
        route: '/manual-vrs',
        color: Colors.orange,
        enabled: authProvider.canAccessFeature('worker'),
      ),
      QuickAction(
        title: 'Thống kê',
        icon: FeatherIcons.barChart,
        route: '/statistics',
        color: Colors.purple,
        enabled: authProvider.canAccessFeature('worker'),
      ),
    ];
  }

  Widget _buildActionCard(BuildContext context, QuickAction action) {
    return Card(
      elevation: action.enabled ? 2 : 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: action.enabled ? () => context.go(action.route) : null,
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                action.icon,
                color: action.enabled ? action.color : Colors.grey[400],
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                action.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: action.enabled ? Colors.grey[800] : Colors.grey[400],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!action.enabled)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  child: Icon(
                    FeatherIcons.lock,
                    color: Colors.grey[400],
                    size: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hoạt động gần đây',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildActivityItem(
                  'Hệ thống khởi động thành công',
                  'Vừa xong',
                  FeatherIcons.checkCircle,
                  Colors.green,
                ),
                const Divider(),
                _buildActivityItem(
                  'Model mới được thêm vào',
                  '2 giờ trước',
                  FeatherIcons.plus,
                  Colors.blue,
                ),
                const Divider(),
                _buildActivityItem(
                  'Kiểm tra chất lượng hoàn tất',
                  '4 giờ trước',
                  FeatherIcons.eye,
                  Colors.orange,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(
    String title,
    String time,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                Text(
                  time,
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuickAction {
  final String title;
  final IconData icon;
  final String route;
  final Color color;
  final bool enabled;

  QuickAction({
    required this.title,
    required this.icon,
    required this.route,
    required this.color,
    required this.enabled,
  });
}
