import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/autovrs_websocket_service.dart';
import '../../widgets/video_frame_widget.dart';
import '../../services/video_frame_service.dart';

class ManualVRSScreen extends StatefulWidget {
  const ManualVRSScreen({super.key});

  @override
  State<ManualVRSScreen> createState() => _ManualVRSScreenState();
}

class _ManualVRSScreenState extends State<ManualVRSScreen> {
  double _magnification = 140;
  int _currentBoard = 4;
  final int _totalBoards = 25;
  late AutoVRSWebSocketService _webSocketService;
  late VideoFrameService _videoFrameService;
  bool _isConnecting = false;
  int _selectedVideoSource = 0; // 0: AutoVRS, 1: Python Video Stream

  @override
  void initState() {
    super.initState();
    _webSocketService = AutoVRSWebSocketService();
    _videoFrameService = VideoFrameService();
    
    // Add listener để debug state changes
    _webSocketService.addListener(() {
      debugPrint('🔄 WebSocket service state changed - isViewingCaptured: ${_webSocketService.isViewingCapturedImage}');
    });
    
    _connectToBackend();
    _connectToVideoStream();
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    _videoFrameService.dispose();
    super.dispose();
  }

  Future<void> _connectToBackend() async {
    setState(() => _isConnecting = true);
    
    try {
      final success = await _webSocketService.connect();
      if (success) {
        debugPrint('Connected to AutoVRS Backend');
      } else {
        debugPrint('Failed to connect to backend');
      }
    } catch (e) {
      debugPrint('Connection error: $e');
    }
    
    setState(() => _isConnecting = false);
  }

  Future<void> _connectToVideoStream() async {
    try {
      final success = await _videoFrameService.connect();
      if (success) {
        debugPrint('Connected to Python Video Stream');
      } else {
        debugPrint('Failed to connect to video stream');
      }
    } catch (e) {
      debugPrint('Video stream connection error: $e');
    }
  }

  Future<void> _captureImage() async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'board_${_currentBoard}_$timestamp.jpg';
      // Luôn enable detection để hiển thị bounding box
      await _webSocketService.captureImage(filename: filename, enableDetection: true);
      
      // DEBUG: Force set test state để kiểm tra UI
      // Uncomment dòng dưới để test UI:
      // _webSocketService.debugSetCapturedState();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chụp ảnh bo $_currentBoard'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi chụp ảnh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _webSocketService,  // Đảm bảo Provider sử dụng đúng instance
      child: LayoutBuilder(
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
                    // Main VRS Image with navigation - Left side
                    Expanded(
                      flex: 2, // Increased from 1 to 2 for wider camera view
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Dynamic title based on viewing mode
                                  Consumer<AutoVRSWebSocketService>(
                                    builder: (context, webSocketService, child) {
                                      return Text(
                                        webSocketService.isViewingCapturedImage
                                            ? 'Ảnh Đã Chụp'
                                            : 'Ảnh Live từ VRS',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: webSocketService.isViewingCapturedImage
                                              ? Colors.blue
                                              : Colors.black,
                                        ),
                                      );
                                    },
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: _currentBoard > 1
                                            ? _previousBoard
                                            : null,
                                        icon: const Icon(FeatherIcons.arrowLeft),
                                        tooltip: 'Bo trước',
                                      ),
                                      Text('$_currentBoard / $_totalBoards'),
                                      IconButton(
                                        onPressed: _currentBoard < _totalBoards
                                            ? _nextBoard
                                            : null,
                                        icon: const Icon(FeatherIcons.arrowRight),
                                        tooltip: 'Bo tiếp theo',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              
                              // Camera Status Indicator
                              Consumer<AutoVRSWebSocketService>(
                                builder: (context, webSocketService, child) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: webSocketService.isViewingCapturedImage
                                          ? Colors.blue.withOpacity(0.1)
                                          : Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: webSocketService.isViewingCapturedImage
                                            ? Colors.blue
                                            : Colors.green,
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          webSocketService.isViewingCapturedImage
                                              ? FeatherIcons.image
                                              : FeatherIcons.video,
                                          size: 14,
                                          color: webSocketService.isViewingCapturedImage
                                              ? Colors.blue
                                              : Colors.green,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          webSocketService.isViewingCapturedImage
                                              ? 'Chế độ xem ảnh'
                                              : 'Live Camera',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: webSocketService.isViewingCapturedImage
                                                ? Colors.blue
                                                : Colors.green,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              
                              const SizedBox(height: 12),
                              
                              // Video Source Selector
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Video Source',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () => setState(() => _selectedVideoSource = 0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _selectedVideoSource == 0 ? Colors.blue : Colors.transparent,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'AutoVRS',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _selectedVideoSource == 0 ? Colors.white : Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => setState(() => _selectedVideoSource = 1),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _selectedVideoSource == 1 ? Colors.green : Colors.transparent,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Video Stream',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: _selectedVideoSource == 1 ? Colors.white : Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 8),
                              
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
                                          child: _selectedVideoSource == 0
                                              ? Stack(
                                                  children: [
                                                    // Live video feed or captured image from AutoVRS WebSocket
                                                    Consumer<AutoVRSWebSocketService>(
                                                      builder: (context, webSocketService, child) {
                                                        if (webSocketService.displayImage != null) {
                                                          // Backend đã vẽ bounding boxes vào ảnh rồi, chỉ cần hiển thị
                                                          return ClipRRect(
                                                            borderRadius: BorderRadius.circular(8),
                                                            child: Image.memory(
                                                              webSocketService.displayImage!,
                                                              fit: BoxFit.cover,
                                                              width: squareSize,
                                                              height: squareSize,
                                                            ),
                                                          );
                                                        } else if (webSocketService.isConnected) {
                                                          return const Center(
                                                            child: Column(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                CircularProgressIndicator(color: Colors.white),
                                                                SizedBox(height: 8),
                                                                Text(
                                                                  'Đang khởi tạo camera...',
                                                                  style: TextStyle(color: Colors.white),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        } else {
                                                          return const Center(
                                                            child: Column(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Icon(Icons.wifi_off, color: Colors.red, size: 48),
                                                                SizedBox(height: 8),
                                                                Text(
                                                                  'Backend Disconnected',
                                                                  style: TextStyle(color: Colors.white),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    ),
                                                    
                                                    // Exit button - chỉ hiển thị khi đang xem ảnh đã chụp
                                                    Consumer<AutoVRSWebSocketService>(
                                                      builder: (context, webSocketService, child) {
                                                        if (webSocketService.isViewingCapturedImage) {
                                                          return Positioned(
                                                            top: 8,
                                                            right: 8,
                                                            child: Container(
                                                              decoration: BoxDecoration(
                                                                color: Colors.black.withOpacity(0.6),
                                                                borderRadius: BorderRadius.circular(20),
                                                              ),
                                                              child: IconButton(
                                                                onPressed: () {
                                                                  webSocketService.returnToLiveCamera();
                                                                },
                                                                icon: const Icon(
                                                                  Icons.close,
                                                                  color: Colors.white,
                                                                ),
                                                                tooltip: 'Quay lại Live Camera',
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                        return const SizedBox.shrink();
                                                      },
                                                    ),
                                                    
                                                    // Connection status indicator
                                                    Positioned(
                                                      top: 8,
                                                      right: 8,
                                                      child: Consumer<AutoVRSWebSocketService>(
                                                        builder: (context, webSocketService, child) {
                                                          return Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: webSocketService.isConnected 
                                                                  ? Colors.green.withOpacity(0.8)
                                                                  : Colors.red.withOpacity(0.8),
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            child: Row(
                                                              mainAxisSize: MainAxisSize.min,
                                                              children: [
                                                                Icon(
                                                                  webSocketService.isConnected 
                                                                      ? Icons.wifi 
                                                                      : Icons.wifi_off,
                                                                  color: Colors.white,
                                                                  size: 16,
                                                                ),
                                                                const SizedBox(width: 4),
                                                                Text(
                                                                  webSocketService.isConnected ? 'AutoVRS' : 'OFF',
                                                                  style: const TextStyle(
                                                                    color: Colors.white,
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    
                                                    // Frame counter
                                                    Positioned(
                                                      bottom: 8,
                                                      left: 8,
                                                      child: Consumer<AutoVRSWebSocketService>(
                                                        builder: (context, webSocketService, child) {
                                                          return Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                            decoration: BoxDecoration(
                                                              color: Colors.black.withOpacity(0.6),
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            child: Text(
                                                              'Frame: ${webSocketService.frameCount}',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : MultiProvider(
                                                  providers: [
                                                    ChangeNotifierProvider.value(value: _videoFrameService),
                                                  ],
                                                  child: VideoFrameWidget(
                                                    width: squareSize,
                                                    height: squareSize,
                                                    fit: BoxFit.contain,
                                                    showControls: true,
                                                    showStats: true,
                                                    placeholder: 'Đang chờ video từ Python server...',
                                                    backgroundColor: Colors.black,
                                                  ),
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
                          'Phán định thủ công',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),

                        const Divider(height: 24),

                        // Info rows
                        _buildInfoRow('Mã Lô:', 'Chưa có'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Số thứ tự bo (Id_board):', '240715-008'),
                        const SizedBox(height: 12),
                        _buildInfoRow('Loại lỗi AI dự đoán:', 'Xước mạch'),

                        const SizedBox(height: 24),

                        // Magnification Slider
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Độ phóng đại',
                                  style: TextStyle(fontSize: 14),
                                ),
                                Text(
                                  '${_magnification.round()}x',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Slider(
                              value: _magnification,
                              min: 50,
                              max: 200,
                              divisions: 30,
                              onChanged: (value) {
                                setState(() => _magnification = value);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Camera Settings
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  context.push('/vrs/light-adjust');
                                },
                                icon: const Icon(FeatherIcons.settings, size: 16),
                                label: const Text('Điều chỉnh đèn'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Capture Image Button
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _captureImage,
                                icon: const Icon(FeatherIcons.camera, size: 16),
                                label: const Text('Chụp lại'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Return to Live Camera Button - chỉ hiển thị khi đang xem ảnh đã chụp
                        Consumer<AutoVRSWebSocketService>(
                          builder: (context, webSocketService, child) {
                            if (webSocketService.isViewingCapturedImage) {
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            webSocketService.returnToLiveCamera();
                                          },
                                          icon: const Icon(FeatherIcons.video, size: 16),
                                          label: const Text('Quay lại Live Camera'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Hiển thị kết quả defect detection
                                  _buildDefectDetectionResults(webSocketService),
                                  
                                  const SizedBox(height: 16),
                                ],
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        // Manual review buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _makeJudgment(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text(
                                  'OK',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _makeJudgment(false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: const Text(
                                  'NG',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Navigation for next board
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _currentBoard < _totalBoards ? _nextBoard : null,
                            icon: const Icon(FeatherIcons.arrowRight),
                            label: const Text('Bo tiếp theo'),
                            style: ElevatedButton.styleFrom(
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
    ));
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ),
      ],
    );
  }

  void _previousBoard() {
    if (_currentBoard > 1) {
      setState(() => _currentBoard--);
    }
  }

  void _nextBoard() {
    if (_currentBoard < _totalBoards) {
      setState(() => _currentBoard++);
    }
  }

  void _makeJudgment(bool isOK) {
    final result = isOK ? 'OK' : 'NG';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã phán định bo $_currentBoard: $result'),
        backgroundColor: isOK ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // Auto-navigate to next board after judgment
    if (_currentBoard < _totalBoards) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _nextBoard();
      });
    }
  }
  
  /// Build widget hiển thị kết quả defect detection
  Widget _buildDefectDetectionResults(AutoVRSWebSocketService webSocketService) {
    final detectionResults = webSocketService.lastDetectionResults;
    final analysis = webSocketService.lastAnalysis;
    
    if (detectionResults == null && analysis == null) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FeatherIcons.search,
                size: 16,
                color: Colors.blue[600],
              ),
              const SizedBox(width: 8),
              Text(
                'Kết quả phát hiện lỗi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Hiển thị số lượng lỗi tổng
          if (analysis != null) ...[
            Row(
              children: [
                const Text('Tổng số lỗi: '),
                Text(
                  '${analysis['total_defects'] ?? 0}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: (analysis['total_defects'] ?? 0) > 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            
            // Hiển thị lỗi theo loại
            if (analysis['defects_by_type'] != null) ...[
              const SizedBox(height: 4),
              ...((analysis['defects_by_type'] as Map<String, dynamic>).entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.only(left: 16, top: 2),
                  child: Row(
                    children: [
                      Text('• ${_getDefectDisplayName(entry.key)}: '),
                      Text(
                        '${entry.value}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }).toList()),
            ],
            
            // Cảnh báo lỗi nghiêm trọng
            if (analysis['has_critical_defects'] == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[300]!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(FeatherIcons.alertTriangle, size: 14, color: Colors.red[600]),
                    const SizedBox(width: 6),
                    Text(
                      'Phát hiện lỗi nghiêm trọng!',
                      style: TextStyle(
                        color: Colors.red[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ] else if (detectionResults != null) ...[
            // Fallback hiển thị cơ bản nếu không có analysis
            Text('Số lỗi phát hiện: ${detectionResults['num_defects'] ?? 0}'),
          ],
        ],
      ),
    );
  }
  
  /// Chuyển đổi tên lỗi kỹ thuật sang tên hiển thị
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
        return 'Người'; // Nếu vẫn detect người
      default:
        return technicalName;
    }
  }
}
