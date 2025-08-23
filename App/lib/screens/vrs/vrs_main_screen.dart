import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vrs_provider.dart';
import '../../services/autovrs_websocket_service.dart';
import 'manual_vrs_screen.dart';
import '../../widgets/defect_list_widget.dart';
import '../../services/local_database_service.dart';

// Map technical defect names to display names (same logic as ManualVRSScreen)
String _getDefectDisplayName(String technicalName) {
  switch (technicalName.toLowerCase()) {
    case 'short_circuit':
      return 'Chập mạch';
    case 'missing_component':
      return 'Thiếu linh kiện';
    case 'damaged_track':
      return 'Đường mạch hỏng';
    case 'solder_bridge':
      return 'Cầu hàn';
    case 'crack':
      return 'Vết nứt';
    case 'person':
      return 'Người';
    default:
      return technicalName;
  }
}

class VRSMainScreen extends StatelessWidget {
  const VRSMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 1200;
        final padding = isSmallScreen ? 16.0 : 24.0;

        // read providers early in the builder so UI below can use dynamic values
        final vrsProvider = Provider.of<VRSProvider>(context);
        final webSocketService = Provider.of<AutoVRSWebSocketService>(context);

        // compute display values
        final lotText =
            (vrsProvider.currentLot.isNotEmpty &&
                vrsProvider.currentLot != 'Chưa có')
            ? vrsProvider.currentLot
            : 'Chưa có';
        final boardText =
            (vrsProvider.currentBoard.isNotEmpty &&
                vrsProvider.currentBoard != 'Chưa có')
            ? vrsProvider.currentBoard
            : 'Chưa có';

        String aiText = 'Không phát hiện lỗi';
        final analysis = webSocketService.lastAnalysis;
        if (analysis != null) {
          if (analysis['defects_by_type'] != null &&
              analysis['defects_by_type'] is Map) {
            final Map defects = analysis['defects_by_type'] as Map;
            if (defects.keys.isNotEmpty) {
              aiText = defects.keys
                  .map((k) => _getDefectDisplayName(k.toString()))
                  .join(', ');
            }
          } else if ((analysis['total_defects'] ?? 0) > 0) {
            aiText = 'Có lỗi';
          }
        }

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
                                    final availableHeight =
                                        constraints.maxHeight;
                                    final squareSize =
                                        availableWidth < availableHeight
                                        ? availableWidth
                                        : availableHeight;

                                    return Center(
                                      child: SizedBox(
                                        width: squareSize,
                                        height: squareSize,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: ValueListenableBuilder<Uint8List?>(
                                            valueListenable:
                                                Provider.of<
                                                      AutoVRSWebSocketService
                                                    >(context, listen: false)
                                                    .currentFrameNotifier,
                                            builder: (context, frameData, child) {
                                              final webSocketService =
                                                  Provider.of<
                                                    AutoVRSWebSocketService
                                                  >(context, listen: false);

                                              if (webSocketService
                                                      .displayImage !=
                                                  null) {
                                                // Backend đã vẽ bounding boxes vào ảnh rồi, chỉ cần hiển thị
                                                return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.memory(
                                                    webSocketService
                                                        .displayImage!,
                                                    fit: BoxFit.cover,
                                                    width: squareSize,
                                                    height: squareSize,
                                                    gaplessPlayback:
                                                        true, // Optimize for smooth video playback
                                                  ),
                                                );
                                              } else if (frameData != null) {
                                                return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  child: Image.memory(
                                                    frameData,
                                                    fit: BoxFit.cover,
                                                    width: squareSize,
                                                    height: squareSize,
                                                    gaplessPlayback:
                                                        true, // Optimize for smooth video playback
                                                  ),
                                                );
                                              } else if (webSocketService
                                                  .isConnected) {
                                                return const Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                      ),
                                                      SizedBox(height: 8),
                                                      Text(
                                                        'Đang khởi tạo camera...',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              } else {
                                                return const Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons.wifi_off,
                                                        color: Colors.red,
                                                        size: 48,
                                                      ),
                                                      SizedBox(height: 8),
                                                      Text(
                                                        'AutoVRS Disconnected',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }
                                            },
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
                                          final availableWidth =
                                              constraints.maxWidth;
                                          final availableHeight =
                                              constraints.maxHeight;
                                          final squareSize =
                                              availableWidth < availableHeight
                                              ? availableWidth
                                              : availableHeight;

                                          return Center(
                                            child: SizedBox(
                                              width: squareSize,
                                              height: squareSize,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade700,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
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
                                          final availableWidth =
                                              constraints.maxWidth;
                                          final availableHeight =
                                              constraints.maxHeight;
                                          final squareSize =
                                              availableWidth < availableHeight
                                              ? availableWidth
                                              : availableHeight;

                                          return Center(
                                            child: SizedBox(
                                              width: squareSize,
                                              height: squareSize,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade200,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
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
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: Colors.grey.shade300, width: 1),
                    borderRadius: BorderRadius.circular(8),
                  ),
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

                        // Info rows (dynamic from providers)
                        _buildInfoRow('Mã Lô (id_lot):', lotText),
                        const SizedBox(height: 12),
                        _buildInfoRow('Số thứ tự bo:', boardText),
                        const SizedBox(height: 12),
                        _buildInfoRow('Loại lỗi AI dự đoán:', aiText),
                        const SizedBox(height: 12),
                        // Total defects for current board
                        FutureBuilder<List<Map<String, dynamic>>>(
                          future: (int.tryParse(boardText) != null)
                              ? LocalDatabaseService().getDefectsByBoard(
                                  int.parse(boardText),
                                )
                              : Future.value([]),
                          builder: (context, snap) {
                            final total = snap.hasData ? snap.data!.length : 0;
                            return _buildInfoRow(
                              'Số lỗi trên bo:',
                              total.toString(),
                            );
                          },
                        ),

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

                        const SizedBox(height: 16),

                        // Defect list for currently selected board
                        DefectListWidget(
                          boardId: int.tryParse(boardText),
                          height: 200,
                        ),

                        const SizedBox(height: 16),

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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // // Manual review button
                        // SizedBox(
                        //   width: double.infinity,
                        //   child: ElevatedButton.icon(
                        //     onPressed: () {
                        //       Navigator.of(context).push(
                        //         MaterialPageRoute(
                        //           builder: (context) => ManualVRSScreen(),
                        //         ),
                        //       );
                        //     },
                        //     icon: const Icon(FeatherIcons.edit3),
                        //     label: const Text('Phán định thủ công'),
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: Colors.orange,
                        //       foregroundColor: Colors.white,
                        //       padding: const EdgeInsets.symmetric(vertical: 12),
                        //     ),
                        //   ),
                        // ),
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
