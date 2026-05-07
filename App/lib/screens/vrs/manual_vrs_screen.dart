import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../services/autovrs_websocket_service.dart';
// import '../../services/video_frame_service.dart'; // Disabled - using AutoVRSWebSocketService
import '../../services/ai_detection_service.dart';
import '../../services/qcamber_gerber_service.dart';
import '../../services/coord_ws_client.dart';
import '../../providers/vrs_provider.dart';
import '../../main.dart';
import '../../widgets/defect_list_widget.dart';
import '../../widgets/gerber_image_widget.dart';
import '../../services/local_database_service.dart';

class ManualVRSScreen extends StatefulWidget {
  const ManualVRSScreen({super.key});

  @override
  State<ManualVRSScreen> createState() => _ManualVRSScreenState();
}

class _ManualVRSScreenState extends State<ManualVRSScreen> {
  String _selectedResolution = 'Full HD'; // VGA, HD, Full HD, 2K
  final double _magnification = 100; // Keep for InteractiveViewer zoom
  // index in _defects (0-based). If no defects, stays at 0.
  int _currentDefectIndex = 0;
  List<Map<String, dynamic>> _defects = [];
  int _defectListReloadToken = 0;
  String? _currentBoardId;
  final _db = LocalDatabaseService();

  // Streamlined state management for capture + AI detection
  late AIDetectionService _aiDetectionService;
  // VideoFrameService disabled - using AutoVRSWebSocketService for SICK camera (port 8999)
  // late VideoFrameService _videoFrameService;
  late QCamberGerberService _gerberService;
  final CoordWsClient _coordClient = CoordWsClient();
  final int _selectedVideoSource = 0; // 0: AutoVRS, 1: Video Stream

  // Camera movement state
  bool _isSendingCoords = false;

  // Capture state management
  bool _isAnalyzing = false;
  bool _hasAnalysisResult = false;
  AIDetectionResult? _analysisResult;
  String?
  _pendingJudgement; // 'OK' or 'NG' when user selects but not yet confirmed
  bool _isLoadingGerber = false;

  // ✅ AOI Image state
  File? _aoiImageFile;
  bool _isLoadingAoiImage = false;

  @override
  void initState() {
    super.initState();

    // Initialize AI Detection Service
    _aiDetectionService = AIDetectionService();
    // _videoFrameService = VideoFrameService(); // Disabled
    _gerberService = context.read<QCamberGerberService>();

    // Kết nối AutoVRS WebSocket khi khởi tạo màn hình
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final webSocketService = Provider.of<AutoVRSWebSocketService>(
        context,
        listen: false,
      );
      _connectToBackend(webSocketService);

      // Connect to coordinator WebSocket for sending coordinates
      _coordClient.connect().catchError((e) {
        debugPrint('⚠️ Failed to connect to coordinator WebSocket: $e');
      });

      // Auto load Gerber and AOI for first defect if available
      if (_defects.isNotEmpty) {
        _loadGerberForCurrentDefect();
        _loadAOIImageForCurrentDefect();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Watch for board changes from provider and reload defects when board changes
    final vrsProvider = Provider.of<VRSProvider>(context, listen: false);
    final board = vrsProvider.currentBoard;
    if (board != _currentBoardId) {
      _currentBoardId = board;
      // Use post-frame callback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDefectsForBoard(board);
      });
    }
  }

  Future<void> _loadDefectsForBoard(String? boardIdStr) async {
    final id = int.tryParse(boardIdStr ?? '');
    if (id == null) {
      if (!mounted) return;
      setState(() {
        _defects = [];
        _currentDefectIndex = 0;
      });
      // Schedule clearImage after build to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _gerberService.clearImage();
      });
      return;
    }

    final list = await _db.getDefectsByBoard(id);
    if (!mounted) return;
    setState(() {
      _defects = list;
      _currentDefectIndex = (_defects.isNotEmpty) ? 0 : 0;
    });

    // Auto-load Gerber and AOI for first defect
    if (_defects.isNotEmpty) {
      _loadGerberForCurrentDefect();
      _loadAOIImageForCurrentDefect();
    } else {
      setState(() => _aoiImageFile = null);
    }
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

  Future<void> _moveCameraToHome() async {
    setState(() => _isSendingCoords = true);

    try {
      final boardId = int.tryParse(_currentBoardId ?? '0') ?? 0;
      final defectId = 0; // Home position

      debugPrint('📤 Sending HOME coords (0, 0) to PLC system');

      // Send home coordinates (0, 0) via WebSocket
      _coordClient.sendCoords(
        boardId: boardId,
        defectId: defectId,
        x: 0.0,
        y: 0.0,
      );

      if (!mounted) return;

      setState(() => _isSendingCoords = false);

      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('✅ Đã gửi lệnh về gốc (0, 0) đến hệ thống PLC'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      debugPrint('✅ Home coordinates sent successfully');
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingCoords = false);

        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi gửi lệnh về gốc: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('❌ Error sending home coordinates: $e');
    }
  }

  Future<void> _moveCameraToDefect() async {
    if (_defects.isEmpty || _currentDefectIndex >= _defects.length) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(
          content: Text('Không có lỗi để di chuyển đến'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSendingCoords = true);

    try {
      final defect = _defects[_currentDefectIndex];

      // Extract PLC coordinates (already scaled)
      double x = 0.0, y = 0.0;
      final plcCoordStr = defect['plc_coor'] as String?;

      if (plcCoordStr != null && plcCoordStr.isNotEmpty) {
        try {
          // Parse plc_coor format: "19.887;5.86" (semicolon separator)
          if (plcCoordStr.contains(';')) {
            final parts = plcCoordStr.split(';');
            if (parts.length >= 2) {
              x = double.tryParse(parts[0].trim()) ?? 0.0;
              y = double.tryParse(parts[1].trim()) ?? 0.0;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to parse plc_coor: $e');
        }
      }

      if (x == 0.0 && y == 0.0) {
        throw Exception('Tọa độ lỗi không hợp lệ (0,0)');
      }

      final boardId = int.tryParse(_currentBoardId ?? '0') ?? 0;
      final defectId = defect['id'] ?? 0;

      debugPrint(
        '📤 Sending coords to operator: board=$boardId, defect=$defectId, x=$x, y=$y',
      );

      // Send coordinates via WebSocket to operator/PLC system
      _coordClient.sendCoords(boardId: boardId, defectId: defectId, x: x, y: y);

      if (!mounted) return;

      setState(() => _isSendingCoords = false);

      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('✅ Đã gửi tọa độ ($x, $y) đến hệ thống PLC'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      debugPrint('✅ Coordinates sent successfully');
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingCoords = false);

        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi gửi tọa độ: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      debugPrint('❌ Error sending coordinates: $e');
    }
  }

  void _changeResolution(String resolution) {
    int width, height;

    switch (resolution) {
      case 'VGA':
        width = 640;
        height = 480;
        break;
      case 'HD':
        width = 1280;
        height = 720;
        break;
      case 'Full HD':
        width = 1920;
        height = 1080;
        break;
      case '2K':
        width = 2560;
        height = 1440;
        break;
      case '4K':
        width = 3840;
        height = 2160;
        break;
      case '20MP':
        width = 5472;
        height = 3648;
        break;
      default:
        width = 1920;
        height = 1080;
    }

    setState(() => _selectedResolution = resolution);

    // Send resolution change to backend via WebSocket
    final webSocketService = Provider.of<AutoVRSWebSocketService>(
      context,
      listen: false,
    );

    webSocketService.sendResolutionChange(width, height);

    debugPrint('📐 Resolution changed to $resolution (${width}x$height)');

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          '✅ Đã thay đổi độ phân giải: $resolution (${width}x$height)',
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 1),
      ),
    );
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
        final filename = 'defect_${_currentDefectIndex + 1}_$timestamp.jpg';
        await webSocketService.captureImage(
          filename: filename,
          enableDetection: true,
        );
        // Get current frame from AutoVRS WebSocket service
        currentFrame = webSocketService.currentFrame;
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
        if (!mounted) return;
        setState(() {
          _analysisResult = result;
          _hasAnalysisResult = true;
          _pendingJudgement =
              null; // reset any previous selection on new analysis
          _isAnalyzing = false;
        });
        // Do NOT persist verdict here. Wait for user to press OK/NG to
        // confirm judgment. Persistence will be handled in _makeJudgment().
      } else {
        throw Exception(_aiDetectionService.lastError ?? "Phân tích thất bại");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });

        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _aiDetectionService.dispose();
    // _videoFrameService.dispose(); // Disabled - using AutoVRSWebSocketService
    _coordClient.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 1200;
        final padding = isSmallScreen ? 16.0 : 24.0;
        final vrsProvider = Provider.of<VRSProvider>(context);
        final webSocketService = Provider.of<AutoVRSWebSocketService>(
          context,
          listen: false,
        );

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
                                              onPressed:
                                                  _defects.isNotEmpty &&
                                                      _currentDefectIndex > 0
                                                  ? _previousDefect
                                                  : null,
                                              icon: const Icon(
                                                FeatherIcons.arrowLeft,
                                              ),
                                              tooltip: 'Lỗi trước',
                                            ),
                                            Text(
                                              '${_defects.isNotEmpty ? _currentDefectIndex + 1 : 0} / ${_defects.length}',
                                            ),
                                            IconButton(
                                              onPressed:
                                                  _defects.isNotEmpty &&
                                                      _currentDefectIndex <
                                                          _defects.length - 1
                                                  ? _nextDefect
                                                  : null,
                                              icon: const Icon(
                                                FeatherIcons.arrowRight,
                                              ),
                                              tooltip: 'Lỗi tiếp theo',
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
                                          // Use full available space to maintain camera aspect ratio
                                          final availableWidth =
                                              constraints.maxWidth;
                                          final availableHeight =
                                              constraints.maxHeight;

                                          return Center(
                                            child: SizedBox(
                                              width: availableWidth,
                                              height: availableHeight,
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
                                                            child: InteractiveViewer(
                                                              panEnabled:
                                                                  _magnification >
                                                                  100,
                                                              scaleEnabled:
                                                                  false,
                                                              child: Transform.scale(
                                                                scale:
                                                                    _magnification /
                                                                    100.0,
                                                                child: Image.memory(
                                                                  webSocketService
                                                                      .capturedImage!,
                                                                  fit: BoxFit
                                                                      .contain,
                                                                  gaplessPlayback:
                                                                      true,
                                                                ),
                                                              ),
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
                                                            child: InteractiveViewer(
                                                              panEnabled:
                                                                  _magnification >
                                                                  100,
                                                              scaleEnabled:
                                                                  false,
                                                              child: Transform.scale(
                                                                scale:
                                                                    _magnification /
                                                                    100.0,
                                                                child: Image.memory(
                                                                  webSocketService
                                                                      .displayImage!,
                                                                  fit: BoxFit
                                                                      .contain,
                                                                  gaplessPlayback:
                                                                      true, // Optimize for smooth video playback
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        } else if (frameData !=
                                                            null) {
                                                          return ClipRRect(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            child: InteractiveViewer(
                                                              panEnabled:
                                                                  _magnification >
                                                                  100,
                                                              scaleEnabled:
                                                                  false,
                                                              child: Transform.scale(
                                                                scale:
                                                                    _magnification /
                                                                    100.0,
                                                                child: Image.memory(
                                                                  frameData,
                                                                  fit: BoxFit
                                                                      .contain,
                                                                  gaplessPlayback:
                                                                      true, // Optimize for smooth video playback
                                                                ),
                                                              ),
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
                                                                child:
                                                                    const SizedBox.shrink(), // Ẩn Frame count
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
                                            child: GerberImageWidget(
                                              isLoading: _isLoadingGerber,
                                              errorMessage:
                                                  _gerberService.lastError,
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

                                                return Center(
                                                  child: SizedBox(
                                                    width: availableWidth,
                                                    height: availableHeight,
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
                                                      child:
                                                          _buildAOIImageWidget(),
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
                          side: BorderSide(
                            color: Colors.grey.shade300,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: SingleChildScrollView(
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
                                _buildInfoRow(
                                  'Mã Lô:',
                                  vrsProvider.currentLot.isNotEmpty
                                      ? vrsProvider.currentLot
                                      : 'Chưa có',
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  'Số thứ tự bo (Id_board):',
                                  vrsProvider.currentBoard.isNotEmpty
                                      ? vrsProvider.currentBoard
                                      : 'Chưa có',
                                ),
                                const SizedBox(height: 12),
                                _buildInfoRow(
                                  'Loại lỗi AI dự đoán:',
                                  _getAIPredictionText(),
                                ),
                                const SizedBox(height: 16),

                                // Defect list for curret board
                                DefectListWidget(
                                  boardId: int.tryParse(
                                    vrsProvider.currentBoard,
                                  ),
                                  height: 220,
                                  reloadToken: _defectListReloadToken,
                                ),

                                const SizedBox(height: 12),

                                // Resolution Selection
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Độ phân giải',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _buildResolutionButton(
                                          'VGA',
                                          '640x480',
                                        ),
                                        _buildResolutionButton(
                                          'HD',
                                          '1280x720',
                                        ),
                                        _buildResolutionButton(
                                          'Full HD',
                                          '1920x1080',
                                        ),
                                        _buildResolutionButton(
                                          '2K',
                                          '2560x1440',
                                        ),
                                        _buildResolutionButton(
                                          '4K',
                                          '3840x2160',
                                        ),
                                        _buildResolutionButton(
                                          '20MP',
                                          '5472x3648',
                                        ),
                                      ],
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

                                // Capture and Analyze Button (hidden when analysis result exists or when viewing captured image)
                                if (!_hasAnalysisResult &&
                                    !webSocketService
                                        .isViewingCapturedImage) ...[
                                  // Camera movement buttons
                                  Row(
                                    children: [
                                      // Về gốc button
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _isSendingCoords
                                              ? null
                                              : _moveCameraToHome,
                                          icon: _isSendingCoords
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
                                              : const Icon(
                                                  FeatherIcons.home,
                                                  size: 16,
                                                ),
                                          label: Text(
                                            _isSendingCoords
                                                ? 'Đang gửi...'
                                                : 'Về gốc',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blueGrey,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Di chuyển Camera button
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _isSendingCoords
                                              ? null
                                              : _moveCameraToDefect,
                                          icon: _isSendingCoords
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
                                              : const Icon(
                                                  FeatherIcons.navigation,
                                                  size: 16,
                                                ),
                                          label: Text(
                                            _isSendingCoords
                                                ? 'Đang gửi...'
                                                : 'Di chuyển Camera',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Chụp lại button
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
                                              : const Icon(
                                                  FeatherIcons.camera,
                                                  size: 16,
                                                ),
                                          label: Text(
                                            _isAnalyzing
                                                ? 'Đang phân tích...'
                                                : 'Chụp lại',
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.blue,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 16),

                                // Return to Live Camera Button - chỉ hiển thị khi đang xem ảnh đã chụp
                                Consumer<AutoVRSWebSocketService>(
                                  builder: (context, webSocketService, child) {
                                    if (webSocketService
                                        .isViewingCapturedImage) {
                                      return Column(
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    // Reset về trạng thái ban đầu
                                                    setState(() {
                                                      _hasAnalysisResult =
                                                          false;
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
                                                    foregroundColor:
                                                        Colors.white,
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
                                          // (Removed) defect detection summary card to reduce UI clutter
                                          const SizedBox.shrink(),
                                          const SizedBox(height: 16),
                                        ],
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),

                                // Manual review: select OK/NG first, then confirm
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed:
                                                (!_hasAnalysisResult ||
                                                    (_pendingJudgement !=
                                                            null &&
                                                        _pendingJudgement !=
                                                            'OK'))
                                                ? null
                                                : () {
                                                    setState(() {
                                                      // select OK, deselect NG
                                                      if (_pendingJudgement ==
                                                          'OK') {
                                                        _pendingJudgement =
                                                            null;
                                                      } else {
                                                        _pendingJudgement =
                                                            'OK';
                                                      }
                                                    });
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  _pendingJudgement == 'OK'
                                                  ? Colors.green
                                                  : Colors.green.shade600,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                            onPressed:
                                                (!_hasAnalysisResult ||
                                                    (_pendingJudgement !=
                                                            null &&
                                                        _pendingJudgement !=
                                                            'NG'))
                                                ? null
                                                : () {
                                                    setState(() {
                                                      if (_pendingJudgement ==
                                                          'NG') {
                                                        _pendingJudgement =
                                                            null;
                                                      } else {
                                                        _pendingJudgement =
                                                            'NG';
                                                      }
                                                    });
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  _pendingJudgement == 'NG'
                                                  ? Colors.red
                                                  : Colors.red.shade600,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
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

                                    const SizedBox(height: 12),

                                    // Confirm button: only enabled after user selects OK/NG
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed:
                                            (_pendingJudgement != null &&
                                                _hasAnalysisResult &&
                                                _defects.isNotEmpty)
                                            ? () => _makeJudgment(
                                                _pendingJudgement == 'OK',
                                              )
                                            : null,
                                        icon: const Icon(FeatherIcons.check),
                                        label: const Text(
                                          'Xác nhận và chuyển lỗi',
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
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
                                    onPressed:
                                        _defects.isNotEmpty &&
                                            _currentDefectIndex <
                                                _defects.length - 1
                                        ? _nextDefect
                                        : null,
                                    icon: const Icon(FeatherIcons.arrowRight),
                                    label: const Text('Chuyển Bo'),
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

  Future<void> _loadGerberForCurrentDefect() async {
    if (_defects.isEmpty) {
      _gerberService.clearImage();
      return;
    }

    if (mounted) {
      setState(() => _isLoadingGerber = true);
    }

    try {
      // Get current defect
      final defect = _defects[_currentDefectIndex];

      // Get model name from database hierarchy: Board -> Lot -> Model
      final boardId =
          int.tryParse(
            Provider.of<VRSProvider>(context, listen: false).currentBoard,
          ) ??
          0;

      final board = await _db.getBoardById(boardId);
      if (board == null) throw Exception('Board not found');

      final lotId = board['tbLotid_lot'];
      final lot = await _db.getLotById(lotId);
      if (lot == null) throw Exception('Lot not found');

      final modelId = lot['tbModelid_model'];
      final model = await _db.getModelById(modelId);
      if (model == null) throw Exception('Model not found');

      // Extract coordinates from defect
      Map<String, dynamic> coordinates = {};
      final coordinatesStr = defect['coordinates'] as String?;

      if (coordinatesStr != null && coordinatesStr.isNotEmpty) {
        try {
          coordinates =
              QCamberGerberService.parseCoordinatesString(coordinatesStr) ?? {};
        } catch (e) {
          debugPrint('Error parsing coordinates: $e');
        }
      }

      // Request Gerber image from QCamber (Port 8686)
      final success = await _gerberService.captureGerberImage(
        modelName: model['name'] ?? 'Model_${model['id_model']}',
        coordinates: coordinates,
        defectType: defect['type'],
        layerName: 'l1', // Changed from l2 to l1
        zoom: 128.0, // Fixed zoom level
      );

      if (success) {
        debugPrint(
          '✅ Gerber image loaded for defect ${_currentDefectIndex + 1}',
        );
      } else {
        debugPrint('❌ Failed to load Gerber: ${_gerberService.lastError}');
      }
    } catch (e) {
      debugPrint('Error loading Gerber: $e');
      if (mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Lỗi tải ảnh Gerber: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingGerber = false);
      }
    }
  }

  void _previousDefect() {
    if (_defects.isNotEmpty && _currentDefectIndex > 0) {
      setState(() => _currentDefectIndex--);
      _loadGerberForCurrentDefect();
      _loadAOIImageForCurrentDefect();
    }
  }

  void _nextDefect() {
    if (_defects.isNotEmpty && _currentDefectIndex < _defects.length - 1) {
      setState(() => _currentDefectIndex++);
      _loadGerberForCurrentDefect();
      _loadAOIImageForCurrentDefect();
    }
  }

  Future<void> _makeJudgment(bool isOK) async {
    final result = isOK ? 'OK' : 'NG';

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(
          'Đã phán định lỗi ${_defects.isNotEmpty ? _currentDefectIndex + 1 : 0}: $result',
        ),
        backgroundColor: isOK ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );

    // Auto-navigate to next defect after judgment
    if (_defects.isNotEmpty && _currentDefectIndex < _defects.length - 1) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _nextDefect();
      });
    }

    // Persist judgment to DB for the current defect
    if (_defects.isNotEmpty &&
        _currentDefectIndex >= 0 &&
        _currentDefectIndex < _defects.length) {
      final current = _defects[_currentDefectIndex];
      final dynamic rawId =
          current['id'] ?? current['id_defect'] ?? current['defect_id'];
      final int? id = rawId is int
          ? rawId
          : int.tryParse(rawId?.toString() ?? '');

      if (id != null) {
        // Determine detected type from latest analysis if available
        String detectedType = '';
        if (_analysisResult != null && _analysisResult!.detections.isNotEmpty) {
          final first = _analysisResult!.detections.first;
          detectedType = first.classNameVi.isNotEmpty
              ? first.classNameVi
              : (first.className.isNotEmpty ? first.className : '');
        }

        // Update database (no error handling - let retry logic in service handle it)
        final rowsAffected = await _db.updateDefect(id, {
          'time': DateTime.now().toIso8601String(),
          'type': detectedType,
          'judgement': result,
        });

        debugPrint(
          '✅ Judgment persisted: defect_id=$id, result=$result, rows=$rowsAffected',
        );

        // Reload list from DB to show updated data (this will update in-memory list)
        setState(() {
          _defectListReloadToken++;
        });

        try {
          await _loadDefectsForBoard(_currentBoardId);
          debugPrint('✅ Defect list reloaded from database');
        } catch (reloadError) {
          debugPrint('⚠️ Failed to reload defect list: $reloadError');
          // Don't show error to user - data is already saved
        }

        // Show success message
        if (mounted) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('✓ Đã lưu phán định: $result'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }

        // Reset local analysis/selection and return to live camera for next defect
        if (!mounted) return;
        setState(() {
          _pendingJudgement = null;
          _analysisResult = null;
          _hasAnalysisResult = false;
        });
        final webSocketService = Provider.of<AutoVRSWebSocketService>(
          context,
          listen: false,
        );
        webSocketService.returnToLiveCamera();
      }
    }
  }

  /// Build widget hiển thị kết quả defect detection
  Widget _buildDefectDetectionResults(
    AutoVRSWebSocketService webSocketService,
  ) {
    // Prefer local analysis result (from immediate AI detection). If absent,
    // fall back to websocket-provided analysis/detectionResults.
    final local = _analysisResult;
    final detectionResults = webSocketService.lastDetectionResults;
    final analysis = webSocketService.lastAnalysis;

    if (local == null && detectionResults == null && analysis == null) {
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

          // Hiển thị số lượng lỗi tổng -- prefer local result
          if (local != null) ...[
            Row(
              children: [
                const Text('Tổng số lỗi: '),
                Text(
                  '${local.detections.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: local.detections.isNotEmpty
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),
            ..._buildLocalDefectTypeRows(local),
          ] else if (analysis != null) ...[
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

  List<Widget> _buildLocalDefectTypeRows(AIDetectionResult local) {
    final Map<String, int> counts = {};
    for (final d in local.detections) {
      final key = (d.classNameVi.isNotEmpty)
          ? d.classNameVi
          : (d.className.isNotEmpty ? d.className : 'Unknown');
      counts[key] = (counts[key] ?? 0) + 1;
    }

    if (counts.isEmpty) return [const Text('Không phát hiện lỗi')];

    final rows = <Widget>[];
    counts.forEach((k, v) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 2),
          child: Row(
            children: [
              Text('• ${_getDefectDisplayName(k)}: '),
              Text('$v', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    });
    return rows;
  }

  /// Chuyển đổi tên lỗi kỹ thuật sang tên hiển thị
  String _getDefectDisplayName(String technicalName) {
    switch (technicalName.toLowerCase()) {
      case 'bamdinhkhongtot':
        return 'Bám Dính Không Tốt';
      case 'chamkim':
        return 'Châm Kim';
      case 'divat':
        return 'Dị vật';
      case 'divatduongmach':
        return 'Dị vật đường mạch';
      case 'khuyetmach':
        return 'Khuyết mạch';
      case 'nganmach':
        return 'Ngắn Mạch';
      case 'thieudong':
        return 'Thiếu Đồng';
      case 'thieudongduongmach':
        return 'Thiếu Đồng Đường Mạch';
      case 'thuadong':
        return 'Thừa Đồng';
      case 'thuadongduongmach':
        return 'Thừa Đồng Đường Mạch';
      case 'vetlom':
        return 'Vết Lõm';
      case 'xuoc':
        return 'Xước';
      case 'other':
        return 'Khác';
      // Legacy names for backward compatibility
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

    // Get unique defect types (prefer Vietnamese name, fallback to className)
    final defectTypes = <String>{};
    for (final detection in _analysisResult!.detections) {
      final t = detection.classNameVi.isNotEmpty
          ? detection.classNameVi
          : (detection.className.isNotEmpty
                ? detection.className
                : 'Không xác định');
      defectTypes.add(t);
    }

    return defectTypes.join(', ');
  }

  /// Load AOI image for current defect from database url_image field
  Future<void> _loadAOIImageForCurrentDefect() async {
    if (_defects.isEmpty || _currentDefectIndex >= _defects.length) {
      setState(() {
        _aoiImageFile = null;
        _isLoadingAoiImage = false;
      });
      return;
    }

    final defect = _defects[_currentDefectIndex];
    final urlImage = defect['url_image'] as String?;

    if (urlImage == null || urlImage.isEmpty) {
      debugPrint('⚠️ No url_image for defect ${_currentDefectIndex + 1}');
      setState(() {
        _aoiImageFile = null;
        _isLoadingAoiImage = false;
      });
      return;
    }

    debugPrint('📷 Loading AOI image: $urlImage');
    await _loadAOIImage(urlImage);
  }

  /// Load AOI image from file path
  Future<void> _loadAOIImage(String filePath) async {
    setState(() => _isLoadingAoiImage = true);

    try {
      final file = File(filePath);
      if (await file.exists()) {
        setState(() {
          _aoiImageFile = file;
          _isLoadingAoiImage = false;
        });
        debugPrint('✅ AOI image loaded: $filePath');
      } else {
        setState(() {
          _aoiImageFile = null;
          _isLoadingAoiImage = false;
        });
        debugPrint('❌ AOI image not found: $filePath');
      }
    } catch (e) {
      setState(() {
        _aoiImageFile = null;
        _isLoadingAoiImage = false;
      });
      debugPrint('❌ Error loading AOI image: $e');
    }
  }

  /// Build AOI image widget with loading/error states
  Widget _buildAOIImageWidget() {
    if (_isLoadingAoiImage) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text(
              'Đang tải ảnh AOI...',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_aoiImageFile != null && _aoiImageFile!.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          _aoiImageFile!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.broken_image, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(
                    'Không thể load ảnh',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _aoiImageFile!.path,
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    // Default placeholder when no defects or no url_image
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            _defects.isEmpty ? 'Chưa có lỗi' : 'Không có ảnh AOI',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildResolutionButton(String label, String resolution) {
    final isSelected = _selectedResolution == label;

    return InkWell(
      onTap: () => _changeResolution(label),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              resolution,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white70 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
