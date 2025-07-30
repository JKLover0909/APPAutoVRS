import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class VRSMainScreen extends StatelessWidget {
  const VRSMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
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
                            child: AspectRatio(
                              aspectRatio: 1.0, // Square aspect ratio
                              child: Container(
                                width: double.infinity,
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
                                    // Defect highlight box
                                    Positioned(
                                      left: 100,
                                      top: 80,
                                      child: Container(
                                        width: 80,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.red,
                                            width: 2,
                                          ),
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
                                Flexible(
                                  child: AspectRatio(
                                    aspectRatio: 1.0, // Square aspect ratio
                                    child: Container(
                                      width: double.infinity,
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
                                          Positioned(
                                            left: 40,
                                            top: 30,
                                            child: Container(
                                              width: 30,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.yellow,
                                                  width: 1,
                                                ),
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
                                Flexible(
                                  child: AspectRatio(
                                    aspectRatio: 1.0, // Square aspect ratio
                                    child: Container(
                                      width: double.infinity,
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
                                          Positioned(
                                            left: 40,
                                            top: 30,
                                            child: Container(
                                              width: 30,
                                              height: 20,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: Colors.blue,
                                                  width: 1,
                                                ),
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

          // Info Panel
          SizedBox(
            width: 320,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thông tin phán định Tự động',
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
                            onPressed: authProvider.canAccessFeature('admin')
                                ? () => context.push('/statistics')
                                : null,
                            icon: const Icon(FeatherIcons.barChart, size: 18),
                            label: const Text('Xem Thống kê'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
    );
  }
}
