import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/autovrs_websocket_service.dart';
import '../../services/video_frame_service.dart';
import '../../services/ai_detection_service.dart';

class ManualVRSScreen extends StatefulWidget {
  const ManualVRSScreen({super.key});

  @override
  State<ManualVRSScreen> createState() => _ManualVRSScreenState();
}

class _ManualVRSScreenState extends State<ManualVRSScreen> {
  double _magnification = 140;
  int _currentBoard = 4;
  final int _totalBoards = 25;

  // Streamlined state management for capture + AI detection
  late AIDetectionService _aiDetectionService;
  late VideoFrameService _videoFrameService;
  final int _selectedVideoSource = 0; // 0: AutoVRS, 1: Video Stream

  // Capture state management
  bool _isAnalyzing = false;
  bool _hasAnalysisResult = false;
  AIDetectionResult? _analysisResult;
  // Uint8List? _capturedFrame; // Removed unused field

  @override
  void initState() {
    super.initState();

    // Initialize AI Detection Service
    _aiDetectionService = AIDetectionService();
    _videoFrameService = VideoFrameService();

    // Kết nối AutoVRS WebSocket khi khởi tạo màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final webSocketService = Provider.of<AutoVRSWebSocketService>(
        context,
        listen: false,
      );
      _connectToBackend(webSocketService);
    });
  }

  Future<void> _connectToBackend(
    AutoVRSWebSocketService webSocketService,
  ) async {
    try {
      final success = await webSocketService.connect();
      if (success) {
        debugPrint('Connected to AutoVRS Backend');
      } else {
        debugPrint('Failed to connect to backend');
      }
    } catch (e) {
      debugPrint('Connection error: $e');
    }
  }

  Future<void> _captureAndAnalyze() async {
    if (_hasAnalysisResult) {
      // User clicked "Tiếp theo" - resume live stream
      setState(() {
        _hasAnalysisResult = false;
        _analysisResult = null;
      });

      // Return to live camera view
      final webSocketService = Provider.of<AutoVRSWebSocketService>(
        context,
        listen: false,
      );
      webSocketService.returnToLiveCamera();

      return;
    }

    // User clicked "Chụp lại" - capture and analyze
    setState(() {
      _isAnalyzing = true;
    });

    try {
      // Get current frame from active video source
      Uint8List? currentFrame;

      if (_selectedVideoSource == 0) {
        // AutoVRS WebSocket
        final webSocketService = Provider.of<AutoVRSWebSocketService>(
          context,
          listen: false,
        );
        currentFrame = webSocketService.currentFrame; // Lấy frame live hiện tại

        // Lưu captured frame và dừng live stream
        if (currentFrame != null) {
          // Set captured image và chuyển sang chế độ xem captured
          webSocketService.setCapturedImage(currentFrame);
          webSocketService.setViewingCapturedImage(true);
        }

        // Also trigger capture for AutoVRS system
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final filename = 'board_${_currentBoard}_$timestamp.jpg';
        await webSocketService.captureImage(
          filename: filename,
          enableDetection: true,
        );
      } else {
        // Video Frame Service
        currentFrame = _videoFrameService.currentFrame;
      }

      if (currentFrame == null) {
        throw Exception('Không có frame để phân tích');
      }

      // Store captured frame for analysis (no need to store separately)
      // _capturedFrame = currentFrame;

      // Run AI detection
      final result = await _aiDetectionService.detectDefects(
        imageData: currentFrame,
      );

      if (result != null && result.success) {
        setState(() {
          _analysisResult = result;
          _hasAnalysisResult = true;
          _isAnalyzing = false;
        });
      } else {
        throw Exception(_aiDetectionService.lastError ?? "Phân tích thất bại");
      }
    } catch (e) {
      setState(() {
        _isAnalyzing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _aiDetectionService.dispose();
    _videoFrameService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 1200;
        final padding = isSmallScreen ? 16.0 : 24.0;

        return Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              Expanded(
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
                            flex:
                                2, // Increased from 1 to 2 for wider camera view
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Dynamic title based on viewing mode
                                        Consumer<AutoVRSWebSocketService>(
                                          builder:
                                              (
                                                context,
                                                webSocketService,
                                                child,
                                              ) {
                                                return Text(
                                                  webSocketService
                                                          .isViewingCapturedImage
                                                      ? 'Ảnh Đã Chụp'
                                                      : 'Ảnh Live từ VRS',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        webSocketService
                                                            .isViewingCapturedImage
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
                                              icon: const Icon(
                                                FeatherIcons.arrowLeft,
                                              ),
                                              tooltip: 'Bo trước',
                                            ),
                                            Text(
                                              '$_currentBoard / $_totalBoards',
                                            ),
                                            IconButton(
                                              onPressed:
                                                  _currentBoard < _totalBoards
                                                  ? _nextBoard
                                                  : null,
                                              icon: const Icon(
                                                FeatherIcons.arrowRight,
                                              ),
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
                                          margin: const EdgeInsets.symmetric(
                                            vertical: 8,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                webSocketService
                                                    .isViewingCapturedImage
                                                ? Colors.blue.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.green.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color:
                                                  webSocketService
                                                      .isViewingCapturedImage
                                                  ? Colors.blue
                                                  : Colors.green,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                webSocketService
                                                        .isViewingCapturedImage
                                                    ? FeatherIcons.image
                                                    : FeatherIcons.video,
                                                size: 14,
                                                color:
                                                    webSocketService
                                                        .isViewingCapturedImage
                                                    ? Colors.blue
                                                    : Colors.green,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                webSocketService
                                                        .isViewingCapturedImage
                                                    ? 'Chế độ xem ảnh'
                                                    : 'Live Camera',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      webSocketService
                                                          .isViewingCapturedImage
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

                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (context, constraints) {
                                          // Calculate square size based on available space
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
                                                  color: Colors.black,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Stack(
                                                  children: [
                                                    // Live video feed or captured image from AutoVRS WebSocket
                                                    ValueListenableBuilder<
                                                      Uint8List?
                                                    >(
                                                      valueListenable:
                                                          Provider.of<
                                                                AutoVRSWebSocketService
                                                              >(
                                                                context,
                                                                listen: false,
                                                              )
                                                              .currentFrameNotifier,
                                                      builder: (context, frameData, child) {
                                                        final webSocketService =
                                                            Provider.of<
                                                              AutoVRSWebSocketService
                                                            >(
                                                              context,
                                                              listen: false,
                                                            );

                                                        // If we have analysis result or currently analyzing, show captured image instead of live stream
                                                        if ((_hasAnalysisResult ||
                                                                _isAnalyzing) &&
                                                            webSocketService
                                                                    .capturedImage !=
                                                                null) {
                                                          return ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            child: Image.memory(
                                                              webSocketService
                                                                  .capturedImage!,
                                                              fit: BoxFit.cover,
                                                              width: squareSize,
                                                              height:
                                                                  squareSize,
                                                              gaplessPlayback:
                                                                  true,
                                                            ),
                                                          );
                                                        } else if (!_hasAnalysisResult &&
                                                            !_isAnalyzing &&
                                                            webSocketService
                                                                    .displayImage !=
                                                                null) {
                                                          // Backend đã vẽ bounding boxes vào ảnh rồi, chỉ cần hiển thị
                                                          return ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            child: Image.memory(
                                                              webSocketService
                                                                  .displayImage!,
                                                              fit: BoxFit.cover,
                                                              width: squareSize,
                                                              height:
                                                                  squareSize,
                                                              gaplessPlayback:
                                                                  true, // Optimize for smooth video playback
                                                            ),
                                                          );
                                                        } else if (frameData !=
                                                            null) {
                                                          return ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            child: Image.memory(
                                                              frameData,
                                                              fit: BoxFit.cover,
                                                              width: squareSize,
                                                              height:
                                                                  squareSize,
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
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                                SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Text(
                                                                  'Đang khởi tạo camera...',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
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
                                                                  Icons
                                                                      .wifi_off,
                                                                  color: Colors
                                                                      .red,
                                                                  size: 48,
                                                                ),
                                                                SizedBox(
                                                                  height: 8,
                                                                ),
                                                                Text(
                                                                  'AutoVRS Disconnected',
                                                                  style: TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    ),

                                                    // Connection status indicator
                                                    Positioned(
                                                      top: 8,
                                                      right: 8,
                                                      child: Consumer<AutoVRSWebSocketService>(
                                                        builder:
                                                            (
                                                              context,
                                                              webSocketService,
                                                              child,
                                                            ) {
                                                              return Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      webSocketService
                                                                          .isConnected
                                                                      ? Colors.green.withValues(
                                                                          alpha:
                                                                              0.8,
                                                                        )
                                                                      : Colors.red.withValues(
                                                                          alpha:
                                                                              0.8,
                                                                        ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Icon(
                                                                      webSocketService
                                                                              .isConnected
                                                                          ? Icons.wifi
                                                                          : Icons.wifi_off,
                                                                      color: Colors
                                                                          .white,
                                                                      size: 16,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 4,
                                                                    ),
                                                                    Text(
                                                                      webSocketService
                                                                              .isConnected
                                                                          ? 'AutoVRS'
                                                                          : 'OFF',
                                                                      style: const TextStyle(
                                                                        color: Colors
                                                                            .white,
                                                                        fontSize:
                                                                            12,
                                                                        fontWeight:
                                                                            FontWeight.bold,
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
                                                        builder:
                                                            (
                                                              context,
                                                              webSocketService,
                                                              child,
                                                            ) {
                                                              return Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          8,
                                                                      vertical:
                                                                          4,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                        alpha:
                                                                            0.6,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        8,
                                                                      ),
                                                                ),
                                                                child: Text(
                                                                  'Frame: ${webSocketService.frameCount}',
                                                                  style: const TextStyle(
                                                                    color: Colors
                                                                        .white,
                                                                    fontSize:
                                                                        12,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                    availableWidth <
                                                        availableHeight
                                                    ? availableWidth
                                                    : availableHeight;

                                                return Center(
                                                  child: SizedBox(
                                                    width: squareSize,
                                                    height: squareSize,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .grey
                                                            .shade700,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Stack(
                                                        children: [
                                                          const Center(
                                                            child: Text(
                                                              'Gerber View',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                                    availableWidth <
                                                        availableHeight
                                                    ? availableWidth
                                                    : availableHeight;

                                                return Center(
                                                  child: SizedBox(
                                                    width: squareSize,
                                                    height: squareSize,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors
                                                            .grey
                                                            .shade200,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Stack(
                                                        children: [
                                                          const Center(
                                                            child: Text(
                                                              'AOI Capture',
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .black,
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
                              _buildInfoRow(
                                'Số thứ tự bo (Id_board):',
                                '240715-008',
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Loại lỗi AI dự đoán:',
                                _getAIPredictionText(),
                              ),

                              const SizedBox(height: 24),

                              // Magnification Slider
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
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
                                      icon: const Icon(
                                        FeatherIcons.settings,
                                        size: 16,
                                      ),
                                      label: const Text('Điều chỉnh đèn'),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Capture and Analyze Button
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _isAnalyzing
                                          ? null
                                          : _captureAndAnalyze,
                                      icon: _isAnalyzing
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : Icon(
                                              _hasAnalysisResult
                                                  ? FeatherIcons.arrowRight
                                                  : FeatherIcons.camera,
                                              size: 16,
                                            ),
                                      label: Text(
                                        _isAnalyzing
                                            ? 'Đang phân tích...'
                                            : (_hasAnalysisResult
                                                  ? 'Tiếp theo'
                                                  : 'Chụp lại'),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _hasAnalysisResult
                                            ? Colors.green
                                            : Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
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
                                                  // Reset về trạng thái ban đầu
                                                  setState(() {
                                                    _hasAnalysisResult = false;
                                                    _analysisResult = null;
                                                  });

                                                  // Quay lại live camera
                                                  webSocketService
                                                      .returnToLiveCamera();
                                                },
                                                icon: const Icon(
                                                  FeatherIcons.video,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Quay lại Live Camera',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.orange,
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Hiển thị kết quả defect detection
                                        _buildDefectDetectionResults(
                                          webSocketService,
                                        ),

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
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
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
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
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
                                  onPressed: _currentBoard < _totalBoards
                                      ? _nextBoard
                                      : null,
                                  icon: const Icon(FeatherIcons.arrowRight),
                                  label: const Text('Bo tiếp theo'),
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
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
        );
      },
    );
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
  Widget _buildDefectDetectionResults(
    AutoVRSWebSocketService webSocketService,
  ) {
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
              Icon(FeatherIcons.search, size: 16, color: Colors.blue[600]),
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
                    color: (analysis['total_defects'] ?? 0) > 0
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ),

            // Hiển thị lỗi theo loại
            if (analysis['defects_by_type'] != null) ...[
              const SizedBox(height: 4),
              ...((analysis['defects_by_type'] as Map<String, dynamic>).entries
                  .map((entry) {
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
                  })
                  .toList()),
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
                    Icon(
                      FeatherIcons.alertTriangle,
                      size: 14,
                      color: Colors.red[600],
                    ),
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

  // Get AI prediction text for display
  String _getAIPredictionText() {
    if (_analysisResult == null || _analysisResult!.detections.isEmpty) {
      return 'Không phát hiện lỗi';
    }

    // Get unique defect types
    final defectTypes = <String>{};
    for (final detection in _analysisResult!.detections) {
      defectTypes.add(detection.classNameVi);
    }

    // Join defect types with comma if multiple
    return defectTypes.join(', ');
  }
}
