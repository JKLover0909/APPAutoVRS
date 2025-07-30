import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/autovrs_websocket_service.dart';

class VRSMainScreen extends StatelessWidget {
  const VRSMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 1200;
        final padding = isSmallScreen ? 16.0 : 24.0;
        
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Display Panel
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    // Main VRS Image - Left side
                    Expanded(
                      flex: 2, // Increased from 1 to 2 for wider camera view
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ảnh Live từ VRS',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    // Calculate square size based on available space
                                    final availableWidth = constraints.maxWidth;
                                    final availableHeight = constraints.maxHeight;
                                    final squareSize = availableWidth < availableHeight 
                                        ? availableWidth 
                                        : availableHeight;
                                    
                                    return Center(
                                      child: SizedBox(
                                        width: squareSize,
                                        height: squareSize,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Stack(
                                            children: [
                                              const Center(
                                                child: Text(
                                                  'Live VRS Image',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Comparison Images - Right side (stacked)
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Gerber View
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ảnh từ Thiết kế Gerber',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final availableWidth = constraints.maxWidth;
                                          final availableHeight = constraints.maxHeight;
                                          final squareSize = availableWidth < availableHeight 
                                              ? availableWidth 
                                              : availableHeight;
                                          
                                          return Center(
                                            child: SizedBox(
                                              width: squareSize,
                                              height: squareSize,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade700,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Stack(
                                                  children: [
                                                    const Center(
                                                      child: Text(
                                                        'Gerber View',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // AOI Capture
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Ảnh từ PCI AOI',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          final availableWidth = constraints.maxWidth;
                                          final availableHeight = constraints.maxHeight;
                                          final squareSize = availableWidth < availableHeight 
                                              ? availableWidth 
                                              : availableHeight;
                                          
                                          return Center(
                                            child: SizedBox(
                                              width: squareSize,
                                              height: squareSize,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Stack(
                                                  children: [
                                                    const Center(
                                                      child: Text(
                                                        'AOI Capture',
                                                        style: TextStyle(
                                                          color: Colors.black,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Info & Action Panel
              SizedBox(
                width: isSmallScreen ? 280 : 320,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Giám sát VRS Auto',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const Divider(height: 24),

                        // Info rows
                        _buildInfoRow('Mã Lô (id_lot):', 'LOT-A-452'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Loại lỗi:', 'Hở mạch'),

                        const SizedBox(height: 24),

                        // AI Result
                        const Text(
                          'Kết quả phán định AI',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 12),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'NG',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Statistics Button
                        Consumer<AuthProvider>(
                          builder: (context, authProvider, _) {
                            return SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: authProvider.isAdminAuthenticated
                                    ? () => context.push('/statistics')
                                    : null,
                                icon: const Icon(FeatherIcons.barChart),
                                label: const Text('Xem thống kê'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // Manual review button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/vrs/manual'),
                            icon: const Icon(FeatherIcons.edit3),
                            label: const Text('Phán định thủ công'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }
}
