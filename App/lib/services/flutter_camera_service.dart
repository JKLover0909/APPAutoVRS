import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Flutter camera service for AutoVRS
/// Handles all camera operations and communicates with Python AI backend
class FlutterCameraService extends ChangeNotifier {
  // Camera related
  List<CameraDescription> _cameras = [];
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  String? _lastError;

  // WebSocket communication with AI backend
  WebSocketChannel? _wsChannel;
  bool _isConnectedToAI = false;
  final String _backendUrl = 'ws://localhost:8999';

  // Image capture and analysis
  Uint8List? _lastCapturedImage;
  Map<String, dynamic>? _lastAnalysisResult;
  bool _isAnalyzing = false;

  // Getters
  List<CameraDescription> get cameras => _cameras;
  bool get isCameraInitialized => _isCameraInitialized;
  bool get isRecording => _isRecording;
  bool get isConnectedToAI => _isConnectedToAI;
  bool get isAnalyzing => _isAnalyzing;
  String? get lastError => _lastError;
  Uint8List? get lastCapturedImage => _lastCapturedImage;
  Map<String, dynamic>? get lastAnalysisResult => _lastAnalysisResult;
  CameraController? get cameraController => _cameraController;

  /// Initialize camera service
  Future<bool> initialize() async {
    try {
      _lastError = null;

      // Get available cameras
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        throw Exception('No cameras found on this device');
      }

      debugPrint('📷 Found ${_cameras.length} cameras');

      // Initialize first camera (usually back camera)
      await _initializeCamera(_cameras.first);

      // Connect to AI backend
      await _connectToAIBackend();

      return true;
    } catch (e) {
      _lastError = 'Camera initialization failed: $e';
      debugPrint('❌ $_lastError');
      notifyListeners();
      return false;
    }
  }

  /// Initialize specific camera
  Future<void> _initializeCamera(CameraDescription camera) async {
    try {
      // Dispose existing controller
      await _cameraController?.dispose();

      // Create new controller
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Initialize controller
      await _cameraController!.initialize();

      _isCameraInitialized = true;
      debugPrint('✅ Camera initialized: ${camera.name}');
      notifyListeners();
    } catch (e) {
      _isCameraInitialized = false;
      throw Exception('Failed to initialize camera: $e');
    }
  }

  /// Switch to different camera
  Future<void> switchCamera(CameraDescription camera) async {
    if (!_cameras.contains(camera)) {
      throw Exception('Camera not available');
    }

    await _initializeCamera(camera);
  }

  /// Connect to SICK camera backend via WebSocket
  Future<void> _connectToAIBackend() async {
    try {
      final uri = Uri.parse(_backendUrl);
      _wsChannel = WebSocketChannel.connect(uri);

      // Listen for binary frames from SICK camera
      _wsChannel!.stream.listen(
        _handleAIMessage,
        onError: (error) {
          debugPrint('❌ WebSocket error: $error');
          _isConnectedToAI = false;
          notifyListeners();
        },
        onDone: () {
          debugPrint('🔌 WebSocket connection closed');
          _isConnectedToAI = false;
          notifyListeners();
        },
      );

      _isConnectedToAI = true;
      debugPrint('✅ Connected to SICK camera backend');
      notifyListeners();
    } catch (e) {
      _isConnectedToAI = false;
      debugPrint('❌ Failed to connect to backend: $e');
      // Don't throw error - app can work without camera
    }
  }

  /// Handle messages from SICK camera backend
  void _handleAIMessage(dynamic message) {
    try {
      // Check if message is binary (JPEG frame)
      if (message is List<int>) {
        // Binary JPEG frame received
        _lastCapturedImage = Uint8List.fromList(message);
        notifyListeners();
        return;
      }

      // Otherwise, try to parse as JSON (initial handshake)
      final data = jsonDecode(message.toString());
      final messageType = data['type'];

      debugPrint('📥 Camera Message: $messageType');

      switch (messageType) {
        case 'connection':
          debugPrint('📷 Camera: ${data['camera']}, ${data['resolution']}');
          break;

        case 'pong':
          debugPrint('🏓 Pong received');
          break;

        case 'error':
          _lastError = 'Camera Error: ${data['message']}';
          notifyListeners();
          break;

        default:
          debugPrint('Unknown message type: $messageType');
      }
    } catch (e) {
      debugPrint('Error handling message: $e');
    }
  }

  /// Capture image and optionally send for AI analysis
  Future<Uint8List?> captureImage({bool analyzeWithAI = true}) async {
    if (!_isCameraInitialized || _cameraController == null) {
      throw Exception('Camera not initialized');
    }

    try {
      debugPrint('📸 Capturing image...');

      // Capture image
      final XFile imageFile = await _cameraController!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();

      _lastCapturedImage = imageBytes;
      debugPrint('✅ Image captured: ${imageBytes.length} bytes');

      // Send to AI for analysis if requested and connected
      if (analyzeWithAI && _isConnectedToAI) {
        await _sendImageForAnalysis(imageBytes);
      }

      notifyListeners();
      return imageBytes;
    } catch (e) {
      _lastError = 'Image capture failed: $e';
      debugPrint('❌ $_lastError');
      notifyListeners();
      return null;
    }
  }

  /// Send image to AI backend for analysis
  Future<void> _sendImageForAnalysis(Uint8List imageBytes) async {
    if (!_isConnectedToAI || _wsChannel == null) {
      debugPrint('⚠️ Not connected to AI backend');
      return;
    }

    try {
      _isAnalyzing = true;
      _lastAnalysisResult = null;
      notifyListeners();

      // Convert to base64
      final String base64Image = base64Encode(imageBytes);

      // Prepare message for AI backend
      final message = {
        'type': 'analyze_image',
        'request_id': 'flutter_${DateTime.now().millisecondsSinceEpoch}',
        'image_data': base64Image,
      };

      debugPrint('🤖 Sending image to AI backend...');
      _wsChannel!.sink.add(jsonEncode(message));
    } catch (e) {
      _isAnalyzing = false;
      _lastError = 'Failed to send image for analysis: $e';
      debugPrint('❌ $_lastError');
      notifyListeners();
    }
  }

  /// Start camera preview (if needed for specific use cases)
  Future<void> startPreview() async {
    if (!_isCameraInitialized) {
      throw Exception('Camera not initialized');
    }

    _isRecording = true;
    debugPrint('📹 Camera preview started');
    notifyListeners();
  }

  /// Stop camera preview
  Future<void> stopPreview() async {
    _isRecording = false;
    debugPrint('⏹️ Camera preview stopped');
    notifyListeners();
  }

  /// Get current camera info
  Map<String, dynamic> getCameraInfo() {
    if (!_isCameraInitialized || _cameraController == null) {
      return {'status': 'not_initialized'};
    }

    return {
      'status': 'initialized',
      'camera_name': _cameraController!.description.name,
      'resolution':
          '${_cameraController!.value.previewSize?.width}x${_cameraController!.value.previewSize?.height}',
      'is_recording': _isRecording,
      'ai_connected': _isConnectedToAI,
    };
  }

  /// Retry AI connection
  Future<void> reconnectToAI() async {
    debugPrint('🔄 Reconnecting to AI backend...');
    await _connectToAIBackend();
  }

  /// Return to live camera view (clear captured image)
  void returnToLiveCamera() {
    _lastCapturedImage = null;
    _lastAnalysisResult = null;
    debugPrint('📹 Returned to live camera view');
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    _cameraController?.dispose();
    _wsChannel?.sink.close();
    super.dispose();
  }
}
