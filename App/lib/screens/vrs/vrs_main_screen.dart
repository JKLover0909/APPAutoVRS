import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/vrs_provider.dart';
// import '../../services/autovrs_websocket_service.dart';
import '../../widgets/defect_list_widget.dart';
import '../../widgets/gerber_image_widget.dart';
import '../../services/local_database_service.dart';
import '../../services/coord_ws_client.dart';
import '../../services/ai_detection_service.dart';
import '../../services/autovrs_websocket_service.dart';
import '../../services/qcamber_gerber_service.dart';

// Map technical defect names to display names (updated for new AI models)
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
      return 'Người';
    default:
      return technicalName;
  }
}

class VRSMainScreen extends StatefulWidget {
  const VRSMainScreen({super.key});

  @override
  State<VRSMainScreen> createState() => _VRSMainScreenState();
}

class _VRSMainScreenState extends State<VRSMainScreen> {
  final CoordWsClient _coordClient = CoordWsClient();
  bool _running = false;
  List<Map<String, dynamic>> _defects = [];
  int _currentIndex = 0;
  // Token to force defect list widget to reload its cached future
  int _defectListReloadToken = 0;
  // Track the last persisted AI verdict so the result panel shows the most
  // recent decision even if _currentIndex advances to the next defect.
  int? _lastPersistedDefectId;
  String? _lastPersistedVerdict;
  String? _lastPersistedType;

  // Gerber service for displaying PCB design images
  late QCamberGerberService _gerberService;
  final bool _isLoadingGerber = false;

  @override
  void initState() {
    super.initState();
    _coordClient.onMessage = _handleWsMessage;
    _gerberService = context.read<QCamberGerberService>();
  }

  @override
  void dispose() {
    _coordClient.disconnect();
    super.dispose();
  }

  void _handleWsMessage(Map<String, dynamic> msg) async {
    final type = msg['type'] ?? '';
    if (type.toString().toLowerCase() == 'process') {
      final defectId = msg['defect_id'];
      debugPrint(
        'VRSMainScreen: PROCESS received from server with defect_id=$defectId',
      );
      // Determine current board id from provider to reload defects after persisting
      final vrsProviderForReload = Provider.of<VRSProvider>(
        context,
        listen: false,
      );
      final boardIdFromProvider = int.tryParse(
        vrsProviderForReload.currentBoard,
      );
      // Run AI on current displayed frame
      final aiService = AIDetectionService();
      // Capture image bytes from AutoVRS service
      final autoService = Provider.of<AutoVRSWebSocketService>(
        context,
        listen: false,
      );
      final imageBytes = autoService.displayImage ?? autoService.currentFrame;

      if (imageBytes != null) {
        final result = await aiService.detectDefects(imageData: imageBytes);
        if (result != null) {
          // send result back to operator server
          _coordClient.sendResult({
            'defect_id': defectId,
            'success': result.success,
            'message': result.message,
            'detections': result.detections
                .map(
                  (d) => {
                    'bbox': d.bbox,
                    'confidence': d.confidence,
                    'class_id': d.classId,
                    'class_name': d.className,
                    'class_name_vi': d.classNameVi,
                    'coordinates': d.coordinates,
                  },
                )
                .toList(),
          });

          // Persist AI judgement into the local database for the defect
          try {
            final hasDetections = result.detections.isNotEmpty;
            final verdict = hasDetections ? 'NG' : 'OK';
            // Choose a representative type string: first detection class or empty
            final detectedType = hasDetections
                ? result.detections.first.className
                : 'none';

            // If defectId is provided and numeric, attempt to update DB
            final id = (defectId is int)
                ? defectId
                : int.tryParse(defectId?.toString() ?? '');
            if (id != null) {
              debugPrint(
                'VRSMainScreen: persisting AI result for defect id=$id (detectedType=$detectedType verdict=$verdict)',
              );
              await LocalDatabaseService().updateDefect(id, {
                'type': detectedType,
                'judgement': verdict,
                'time': DateTime.now().toIso8601String(),
              });
              // bump the reload token so UI lists refresh
              setState(() {
                _defectListReloadToken++;
              });
              // record last persisted verdict/type
              _lastPersistedDefectId = id;
              _lastPersistedVerdict = verdict;
              _lastPersistedType = detectedType;

              // If we know the board id, reload defects and advance to next defect
              if (boardIdFromProvider != null) {
                try {
                  final reloaded = await LocalDatabaseService()
                      .getDefectsByBoard(boardIdFromProvider);
                  final foundIndex = reloaded.indexWhere((d) {
                    final did = d['id_defect'] ?? d['id'] ?? d['defect_id'];
                    if (did == null) return false;
                    final parsed = (did is int)
                        ? did
                        : int.tryParse(did.toString());
                    return parsed == id;
                  });

                  debugPrint(
                    'VRSMainScreen: reloaded defects=${reloaded.length} foundIndex=$foundIndex',
                  );

                  int nextIndex = 0;
                  if (foundIndex != -1 && foundIndex < reloaded.length - 1) {
                    nextIndex = foundIndex + 1;
                  } else if (foundIndex == -1) {
                    // Persisted defect not found in reloaded list. Resume from
                    // the previous index (clamped) so we don't loop back to start
                    // and repeat defects.
                    final clamped = (_currentIndex >= reloaded.length)
                        ? reloaded.length - 1
                        : _currentIndex;
                    nextIndex = clamped < 0 ? 0 : clamped;
                  } else {
                    // processed last defect -> stop workflow
                    nextIndex = reloaded.length;
                  }

                  setState(() {
                    _defects = reloaded;
                    _currentIndex = nextIndex;
                    debugPrint(
                      'VRSMainScreen: advanced to index=$_currentIndex after persist',
                    );
                    if (_currentIndex >= _defects.length) {
                      _running = false;
                      debugPrint(
                        'VRSMainScreen: no more defects - stopping workflow',
                      );
                    }
                  });
                  // After successful persist and index advance, send next coords if still running
                  if (mounted && _running && _currentIndex < _defects.length) {
                    _sendCurrentCoordsIfRunning();
                  }
                } catch (e) {
                  debugPrint('Error reloading defects after persist: $e');
                }
              } else {
                // Fallback: update in-memory list and increment index
                final idx = _defects.indexWhere((d) {
                  final did = d['id_defect'] ?? d['id'] ?? d['defect_id'];
                  if (did == null) return false;
                  final parsed = (did is int)
                      ? did
                      : int.tryParse(did.toString());
                  return parsed == id;
                });
                if (idx != -1) {
                  setState(() {
                    _defects[idx]['type'] = detectedType;
                    _defects[idx]['judgement'] = verdict;
                    if (idx < _defects.length - 1) {
                      _currentIndex = idx + 1;
                    } else {
                      _running = false;
                    }
                    _defectListReloadToken++;
                  });
                  // record last persisted verdict/type for in-memory update
                  _lastPersistedDefectId =
                      (_defects[idx]['id_defect'] ??
                              _defects[idx]['id'] ??
                              _defects[idx]['defect_id'])
                          is int
                      ? (_defects[idx]['id_defect'] ??
                                _defects[idx]['id'] ??
                                _defects[idx]['defect_id'])
                            as int
                      : int.tryParse(
                          (_defects[idx]['id_defect'] ??
                                  _defects[idx]['id'] ??
                                  _defects[idx]['defect_id'])
                              .toString(),
                        );
                  _lastPersistedVerdict = verdict;
                  _lastPersistedType = detectedType;
                  // send next coords if still running
                  if (mounted && _running && _currentIndex < _defects.length) {
                    _sendCurrentCoordsIfRunning();
                  }
                }
              }
            } else {
              // defect_id from server was not numeric; fallback to using current in-memory defect at _currentIndex
              debugPrint(
                'VRSMainScreen: defect_id from server not numeric, falling back to in-memory index=$_currentIndex',
              );
              if (_defects.isNotEmpty &&
                  _currentIndex >= 0 &&
                  _currentIndex < _defects.length) {
                final fallbackIdRaw =
                    _defects[_currentIndex]['id_defect'] ??
                    _defects[_currentIndex]['id'] ??
                    _defects[_currentIndex]['defect_id'];
                final fallbackId = (fallbackIdRaw is int)
                    ? fallbackIdRaw
                    : int.tryParse(fallbackIdRaw?.toString() ?? '');
                if (fallbackId != null) {
                  debugPrint(
                    'VRSMainScreen: persisting AI result for in-memory defect id=$fallbackId',
                  );
                  try {
                    await LocalDatabaseService().updateDefect(fallbackId, {
                      'type': detectedType,
                      'judgement': verdict,
                      'time': DateTime.now().toIso8601String(),
                    });
                    setState(() {
                      _defects[_currentIndex]['type'] = detectedType;
                      _defects[_currentIndex]['judgement'] = verdict;
                      if (_currentIndex < _defects.length - 1) {
                        _currentIndex++;
                      } else {
                        _running = false;
                      }
                      _defectListReloadToken++;
                    });
                    // record last persisted verdict/type for fallback persist
                    _lastPersistedDefectId = fallbackId;
                    _lastPersistedVerdict = verdict;
                    _lastPersistedType = detectedType;
                    // send next coords if still running
                    if (mounted &&
                        _running &&
                        _currentIndex < _defects.length) {
                      _sendCurrentCoordsIfRunning();
                    }
                  } catch (e) {
                    debugPrint('VRSMainScreen: fallback persist failed: $e');
                  }
                } else {
                  debugPrint(
                    'VRSMainScreen: fallbackId is null, cannot persist',
                  );
                }
              } else {
                debugPrint(
                  'VRSMainScreen: no in-memory defect available to fallback',
                );
              }
            }
          } catch (e) {
            debugPrint('Failed to persist AI result: $e');
          }
        }
      }

      // no unconditional advance here; advances and sending are handled
      // immediately after successful persistence above to avoid double-advancing
    }
  }

  Future<void> _sendCurrentCoordsIfRunning() async {
    if (!_running) {
      debugPrint(
        'VRSMainScreen: _sendCurrentCoordsIfRunning called but workflow not running',
      );
      return;
    }
    debugPrint(
      'VRSMainScreen: _sendCurrentCoordsIfRunning start - defectsLoaded=${_defects.length}',
    );
    // Fetch defects for the currently selected board and send the FIRST defect's coordinates
    try {
      // If we already loaded defects for this run, prefer them; otherwise fetch
      List<Map<String, dynamic>> defectsForBoard = _defects;
      if (defectsForBoard.isEmpty) {
        // Try to determine board id from UI/provider
        // In most cases vrsProvider.currentBoard holds the board id string
        final vrsProvider = Provider.of<VRSProvider>(context, listen: false);
        final boardStr = vrsProvider.currentBoard;
        final parsedBoardId = int.tryParse(boardStr);
        if (parsedBoardId != null) {
          defectsForBoard = await LocalDatabaseService().getDefectsByBoard(
            parsedBoardId,
          );
        }
      }

      if (defectsForBoard.isEmpty) {
        debugPrint('VRSMainScreen: no defects found for board after DB fetch');
        return;
      }

      // Use the current index in the workflow (fall back to 0 if out of bounds)
      final int idx =
          (_currentIndex >= 0 && _currentIndex < defectsForBoard.length)
          ? _currentIndex
          : 0;
      final current = defectsForBoard[idx];
      debugPrint(
        'VRSMainScreen: preparing to send coords for defect index=$idx (of ${defectsForBoard.length})',
      );
      final boardId = current['tbBoardid_board'] ?? current['board_id'];
      final defectId =
          current['id'] ?? current['id_defect'] ?? current['defect_id'];

      num x = 0;
      num y = 0;

      // Use plc_coor column for PLC movement (already scaled)
      final plcCoords = current['plc_coor'];
      if (plcCoords != null) {
        if (plcCoords is String) {
          debugPrint('VRSMainScreen: raw plc_coor string found: $plcCoords');
          // Send raw string plc coordinates (e.g. "19.887;5.86")
          if (boardId != null && defectId != null) {
            debugPrint(
              'VRSMainScreen: sending raw plc_coor string for defect $defectId (index=$idx)',
            );
            _coordClient.sendCoordsString(
              boardId: boardId,
              defectId: defectId,
              coords: plcCoords,
            );
            return;
          } else {
            debugPrint(
              'VRSMainScreen: cannot send raw plc_coor string - missing ids (index=$idx)',
            );
          }
        }
        // Otherwise fallthrough to numeric parsing
        if (plcCoords is String) {
          // Parse plc_coor format: "19.887;5.86" (semicolon separator)
          try {
            if (plcCoords.contains(';')) {
              final parts = plcCoords.split(';');
              if (parts.length >= 2) {
                x = double.tryParse(parts[0].trim()) ?? 0;
                y = double.tryParse(parts[1].trim()) ?? 0;
              }
            } else if (plcCoords.contains(',')) {
              // Fallback for comma separator
              final parts = plcCoords.split(',');
              if (parts.length >= 2) {
                x = double.tryParse(parts[0].trim()) ?? 0;
                y = double.tryParse(parts[1].trim()) ?? 0;
              }
            }
          } catch (e) {
            debugPrint('Failed to parse plc_coor: $e');
          }
        } else if (plcCoords is Map) {
          x = (plcCoords['x'] ?? 0) is num
              ? plcCoords['x'] as num
              : double.tryParse('${plcCoords['x']}') ?? 0;
          y = (plcCoords['y'] ?? 0) is num
              ? plcCoords['y'] as num
              : double.tryParse('${plcCoords['y']}') ?? 0;
        }
      }

      if (boardId != null && defectId != null) {
        debugPrint(
          'VRSMainScreen: sending coords -> board=$boardId defect=$defectId index=$idx x=$x y=$y',
        );
        _coordClient.sendCoords(
          boardId: boardId,
          defectId: defectId,
          x: x,
          y: y,
        );
      }
    } catch (e) {
      debugPrint('Error sending first defect coords: $e');
    }
  }

  Future<void> _startWorkflow(int boardId) async {
    // load defects
    final list = await LocalDatabaseService().getDefectsByBoard(boardId);
    setState(() {
      _defects = list;
      _currentIndex = 0;
      _running = true;
    });

    try {
      await _coordClient.connect();
      debugPrint('VRSMainScreen: coord ws connected');
    } catch (e) {
      debugPrint('VRSMainScreen: coord ws connection failed: $e');
    }
    // send first coords
    await _sendCurrentCoordsIfRunning();
  }

  Future<void> _stopWorkflow() async {
    setState(() {
      _running = false;
    });
    await _coordClient.disconnect();
    debugPrint('VRSMainScreen: stopped workflow and disconnected coord ws');
  }

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
        final detectionResults = webSocketService.lastDetectionResults;

        // DEBUG: Log raw data
        debugPrint('🔍 VRSMain aiText calculation:');
        debugPrint(
          '  detectionResults: ${detectionResults != null ? 'EXISTS' : 'NULL'}',
        );
        debugPrint('  analysis: ${analysis != null ? 'EXISTS' : 'NULL'}');

        // Ưu tiên lấy từ lastDetectionResults vì có class_name_vi
        if (detectionResults != null && detectionResults.isNotEmpty) {
          // lastDetectionResults là Map, cần lấy 'detections' array bên trong
          final detections = detectionResults['detections'];
          debugPrint(
            '  detectionResults[detections]: ${detections != null ? 'List of ${(detections as List?)?.length}' : 'NULL'}',
          );
          if (detections != null &&
              detections is List &&
              detections.isNotEmpty) {
            // Chỉ lấy lỗi có confidence cao nhất
            var highestConfDetection = detections[0];
            double highestConf = (highestConfDetection['confidence'] ?? 0.0)
                .toDouble();

            for (final d in detections) {
              final conf = (d['confidence'] ?? 0.0).toDouble();
              if (conf > highestConf) {
                highestConf = conf;
                highestConfDetection = d;
              }
            }

            final nameVi =
                highestConfDetection['class_name_vi'] ??
                highestConfDetection['className'] ??
                'Unknown';
            aiText = '$nameVi (${(highestConf * 100).toStringAsFixed(1)}%)';
            debugPrint(
              '  ✅ aiText from detectionResults (highest conf): $aiText',
            );
          }
        } else if (analysis != null) {
          // Fallback: dùng analysis nhưng lấy từ detections nếu có
          final detections = analysis['detections'];
          debugPrint(
            '  analysis[detections]: ${detections != null ? 'List of ${(detections as List?)?.length}' : 'NULL'}',
          );
          if (detections != null &&
              detections is List &&
              detections.isNotEmpty) {
            // Chỉ lấy lỗi có confidence cao nhất từ analysis
            var highestConfDetection = detections[0];
            double highestConf = (highestConfDetection['confidence'] ?? 0.0)
                .toDouble();

            for (final d in detections) {
              final conf = (d['confidence'] ?? 0.0).toDouble();
              if (conf > highestConf) {
                highestConf = conf;
                highestConfDetection = d;
              }
            }

            final nameVi =
                highestConfDetection['class_name_vi'] ??
                highestConfDetection['class_name'] ??
                'Unknown';
            final displayName = _getDefectDisplayName(nameVi.toString());
            aiText =
                '$displayName (${(highestConf * 100).toStringAsFixed(1)}%)';
            debugPrint('  ✅ aiText from analysis (highest conf): $aiText');
          } else if ((analysis['total_defects'] ?? 0) > 0) {
            aiText = 'Có lỗi';
            debugPrint('  ⚠️ aiText fallback: $aiText');
          }
        }
        debugPrint('  FINAL aiText: $aiText');

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
                                      child: GerberImageWidget(
                                        isLoading: _isLoadingGerber,
                                        errorMessage: _gerberService.lastError,
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
                    child: SingleChildScrollView(
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
                              final total = snap.hasData
                                  ? snap.data!.length
                                  : 0;
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

                          // Dynamic AI Result Panel - shows OK (green) or NG (red)
                          Builder(
                            builder: (context) {
                              String verdictShort = 'OK';
                              Color bgColor = Colors.green.shade50;
                              Color txtColor = Colors.green.shade600;
                              String detailText = aiText;

                              // Prefer the last persisted verdict/type when available.
                              // This ensures the result card shows the most recent
                              // persisted AI decision even if _currentIndex has moved on.
                              if (_lastPersistedVerdict != null) {
                                verdictShort = _lastPersistedVerdict!
                                    .toUpperCase();
                                if (verdictShort == 'OK') {
                                  bgColor = Colors.green.shade50;
                                  txtColor = Colors.green.shade600;
                                  detailText = 'Không phát hiện lỗi';
                                } else {
                                  bgColor = Colors.red.shade50;
                                  txtColor = Colors.red.shade600;
                                  if (_lastPersistedType != null &&
                                      _lastPersistedType!.isNotEmpty) {
                                    detailText = _getDefectDisplayName(
                                      _lastPersistedType!,
                                    );
                                  } else {
                                    detailText = aiText;
                                  }
                                }
                              } else if (_defects.isNotEmpty &&
                                  _currentIndex < _defects.length) {
                                final cur = _defects[_currentIndex];
                                final j = cur['judgement']
                                    ?.toString()
                                    .toUpperCase();
                                if (j != null && j.isNotEmpty) {
                                  verdictShort = j;
                                  if (verdictShort == 'OK') {
                                    bgColor = Colors.green.shade50;
                                    txtColor = Colors.green.shade600;
                                    detailText = 'Không phát hiện lỗi';
                                  } else {
                                    bgColor = Colors.red.shade50;
                                    txtColor = Colors.red.shade600;
                                    // show detected type if available
                                    detailText =
                                        (cur['type'] != null &&
                                            cur['type'].toString().isNotEmpty)
                                        ? _getDefectDisplayName(
                                            cur['type'].toString(),
                                          )
                                        : aiText;
                                  }
                                } else {
                                  // no persisted judgement yet - fallback to lastAnalysis
                                  if (analysis != null) {
                                    final hasDefects =
                                        (analysis['total_defects'] ?? 0) > 0 ||
                                        (analysis['defects_by_type'] is Map &&
                                            (analysis['defects_by_type'] as Map)
                                                .keys
                                                .isNotEmpty);
                                    if (hasDefects) {
                                      verdictShort = 'NG';
                                      bgColor = Colors.red.shade50;
                                      txtColor = Colors.red.shade600;
                                    } else {
                                      verdictShort = 'OK';
                                      bgColor = Colors.green.shade50;
                                      txtColor = Colors.green.shade600;
                                    }
                                  }
                                }
                              } else {
                                // no defect in memory - use analysis
                                if (analysis != null) {
                                  final hasDefects =
                                      (analysis['total_defects'] ?? 0) > 0 ||
                                      (analysis['defects_by_type'] is Map &&
                                          (analysis['defects_by_type'] as Map)
                                              .keys
                                              .isNotEmpty);
                                  if (hasDefects) {
                                    verdictShort = 'NG';
                                    bgColor = Colors.red.shade50;
                                    txtColor = Colors.red.shade600;
                                  } else {
                                    verdictShort = 'OK';
                                    bgColor = Colors.green.shade50;
                                    txtColor = Colors.green.shade600;
                                  }
                                }
                              }

                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      verdictShort,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: txtColor,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      detailText,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: txtColor.withOpacity(0.9),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 16),

                          // Defect list for currently selected board
                          DefectListWidget(
                            boardId: int.tryParse(boardText),
                            height: 200,
                            reloadToken: _defectListReloadToken,
                          ),

                          const SizedBox(height: 16),

                          // Start / Stop operator-driven workflow
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      (boardText != 'Chưa có' && !_running)
                                      ? () {
                                          final bId = int.tryParse(boardText);
                                          if (bId != null) _startWorkflow(bId);
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text('Bắt đầu'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _running ? _stopWorkflow : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                  ),
                                  child: const Text('Dừng'),
                                ),
                              ),
                            ],
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
