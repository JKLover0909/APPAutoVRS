import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import '../providers/navigation_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/sidebar_navigation.dart';
import '../widgets/password_dialog.dart';

class MainLayout extends StatelessWidget {
  final Widget child;

  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar Navigation
          const SidebarNavigation(),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Top Bar
                _buildTopBar(context),

                // Content
                Expanded(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Consumer<NavigationProvider>(
      builder: (context, navigationProvider, _) {
        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Back Button
                if (navigationProvider.canGoBack)
                  IconButton(
                    onPressed: () => navigationProvider.goBack(),
                    icon: const Icon(FeatherIcons.arrowLeft),
                    color: Colors.white,
                    tooltip: 'Quay lại',
                  ),

                // Title
                Expanded(
                  child: Text(
                    navigationProvider.getViewTitle(
                      GoRouterState.of(context).name ?? 'home',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                // Current Time
                _buildCurrentTime(),

                const SizedBox(width: 16),

                // User Menu
                _buildUserMenu(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentTime() {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(
        const Duration(seconds: 1),
        (_) => DateTime.now(),
      ),
      builder: (context, snapshot) {
        final now = snapshot.data ?? DateTime.now();
        return Text(
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} '
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        );
      },
    );
  }

  Widget _buildUserMenu(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return PopupMenuButton<String>(
          icon: const Icon(FeatherIcons.user, color: Colors.white),
          onSelected: (value) {
            switch (value) {
              case 'logout':
                authProvider.logout();
                break;
              case 'worker_login':
                _showPasswordDialog(context, 'worker');
                break;
              case 'admin_login':
                _showPasswordDialog(context, 'admin');
                break;
            }
          },
          itemBuilder: (context) => [
            if (!authProvider.hasAnyAuth) ...[
              const PopupMenuItem(
                value: 'worker_login',
                child: Row(
                  children: [
                    Icon(FeatherIcons.user),
                    SizedBox(width: 8),
                    Text('Đăng nhập Worker'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'admin_login',
                child: Row(
                  children: [
                    Icon(FeatherIcons.shield),
                    SizedBox(width: 8),
                    Text('Đăng nhập Admin'),
                  ],
                ),
              ),
            ] else ...[
              PopupMenuItem(
                enabled: false,
                child: Row(
                  children: [
                    Icon(
                      authProvider.isAdminAuthenticated
                          ? FeatherIcons.shield
                          : FeatherIcons.user,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      authProvider.isAdminAuthenticated ? 'Admin' : 'Worker',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(FeatherIcons.logOut),
                    SizedBox(width: 8),
                    Text('Đăng xuất'),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showPasswordDialog(BuildContext context, String role) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PasswordDialog(
        title: role == 'admin' ? 'Đăng nhập Admin' : 'Đăng nhập Worker',
        onAuthenticated: (password) async {
          final authProvider = context.read<AuthProvider>();
          bool success = false;

          if (role == 'admin') {
            success = await authProvider.authenticateAdmin(password);
          } else {
            success = await authProvider.authenticateWorker(password);
          }

          return success;
        },
      ),
    );
  }
}
