import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 24,
        crossAxisSpacing: 24,
        childAspectRatio: 1.5,
        children: [
          _buildStatisticsCard(
            context,
            title: 'Thống kê phán định',
            description: 'Xem tỉ lệ NG/OK và tỉ lệ lỗi giả theo từng lô hàng.',
            icon: FeatherIcons.pieChart,
            color: Colors.purple.shade500,
            route: '/ng-rate',
          ),
          _buildStatisticsCard(
            context,
            title: 'Thống kê loại lỗi',
            description:
                'Xem chi tiết số lượng và phân loại các lỗi trong một lô hàng cụ thể.',
            icon: FeatherIcons.list,
            color: Colors.teal.shade500,
            route: '/select-lot',
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  description,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
