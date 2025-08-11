import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import '../services/flutter_camera_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late FlutterCameraService _cameraService;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameraService = Provider.of<FlutterCameraService>(context, listen: false);
    
    final success = await _cameraService.initialize();
    
    setState(() {
      _isInitializing = false;
    });
    
    if (!success) {
      _showErrorDialog('Camera initialization failed: ${_cameraService.lastError}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AutoVRS Camera'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          Consumer<FlutterCameraService>(
            builder: (context, service, child) {
              return IconButton(
                icon: Icon(
                  service.isConnectedToAI ? Icons.cloud_done : Icons.cloud_off,
                  color: service.isConnectedToAI ? Colors.green : Colors.red,
                ),
                onPressed: () {
                  if (!service.isConnectedToAI) {
                    service.reconnectToAI();
                  }
                },
                tooltip: service.isConnectedToAI ? 'AI Connected' : 'AI Disconnected - Tap to reconnect',
              );
            },
          ),
        ],
      ),
      body: _isInitializing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing camera...'),
                ],
              ),
            )
          : Consumer<FlutterCameraService>(
              builder: (context, service, child) {
                if (!service.isCameraInitialized) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Camera not available',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          service.lastError ?? 'Unknown error',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _initializeCamera(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Camera Preview
                    Expanded(
                      flex: 3,
                      child: _buildCameraPreview(service),
                    ),
                    
                    // Analysis Results
                    Expanded(
                      flex: 1,
                      child: _buildAnalysisResults(service),
                    ),
                    
                    // Controls
                    _buildControls(service),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildCameraPreview(FlutterCameraService service) {
    if (service.lastCapturedImage != null) {
      // Show captured image
      return Container(
        width: double.infinity,
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              service.lastCapturedImage!,
              fit: BoxFit.contain,
            ),
            
            // Detection overlays
            if (service.lastAnalysisResult != null) 
              _buildDetectionOverlay(service.lastAnalysisResult!),
            
            // Back to live button
            Positioned(
              top: 16,
              left: 16,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    service.returnToLiveCamera();
                  });
                },
                icon: const Icon(Icons.videocam),
                label: const Text('Live Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Show live camera preview
    return Container(
      width: double.infinity,
      color: Colors.black,
      child: service.cameraController != null
          ? CameraPreview(service.cameraController!)
          : const Center(
              child: Text(
                'Camera preview not available',
                style: TextStyle(color: Colors.white),
              ),
            ),
    );
  }

  Widget _buildDetectionOverlay(Map<String, dynamic> analysisResult) {
    final detections = analysisResult['detections'] as List<dynamic>? ?? [];
    
    return CustomPaint(
      painter: DetectionOverlayPainter(detections),
      size: Size.infinite,
    );
  }

  Widget _buildAnalysisResults(FlutterCameraService service) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined),
              const SizedBox(width: 8),
              Text(
                'Analysis Results',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (service.isAnalyzing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          if (service.lastAnalysisResult != null) ...[
            _buildAnalysisCard(service.lastAnalysisResult!),
          ] else if (service.isAnalyzing) ...[
            const Text('Analyzing image with AI...'),
          ] else if (!service.isConnectedToAI) ...[
            const Text(
              'AI backend not connected. Images will be captured without analysis.',
              style: TextStyle(color: Colors.orange),
            ),
          ] else ...[
            const Text('Capture an image to see analysis results'),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> result) {
    final numDefects = result['num_defects'] ?? 0;
    final detections = result['detections'] as List<dynamic>? ?? [];
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  numDefects > 0 ? Icons.warning : Icons.check_circle,
                  color: numDefects > 0 ? Colors.red : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  '$numDefects Defects Found',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: numDefects > 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            
            if (detections.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...detections.take(3).map((detection) {
                final className = detection['class_name'] ?? 'Unknown';
                final confidence = detection['confidence'] ?? 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '• $className (${(confidence * 100).toStringAsFixed(1)}%)',
                    style: const TextStyle(fontSize: 12),
                  ),
                );
              }),
              
              if (detections.length > 3)
                Text(
                  '... and ${detections.length - 3} more',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControls(FlutterCameraService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Camera switch button
          IconButton(
            onPressed: service.cameras.length > 1 ? () => _showCameraSwitchDialog(service) : null,
            icon: const Icon(Icons.switch_camera),
            iconSize: 32,
            tooltip: 'Switch Camera',
          ),
          
          // Capture button
          GestureDetector(
            onTap: service.isAnalyzing ? null : () => service.captureImage(analyzeWithAI: true),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: service.isAnalyzing ? Colors.grey : Colors.blue[700],
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(
                service.isAnalyzing ? Icons.hourglass_empty : Icons.camera_alt,
                color: Colors.white,
                size: 32,
              ),
            ),
          ),
          
          // AI toggle button
          IconButton(
            onPressed: service.isConnectedToAI ? null : () => service.reconnectToAI(),
            icon: Icon(
              service.isConnectedToAI ? Icons.smart_toy : Icons.smart_toy_outlined,
              color: service.isConnectedToAI ? Colors.green : Colors.grey,
            ),
            iconSize: 32,
            tooltip: service.isConnectedToAI ? 'AI Connected' : 'Reconnect to AI',
          ),
        ],
      ),
    );
  }

  void _showCameraSwitchDialog(FlutterCameraService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Switch Camera'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: service.cameras.map((camera) {
            return ListTile(
              title: Text(camera.name),
              subtitle: Text(camera.lensDirection.toString()),
              onTap: () {
                Navigator.pop(context);
                service.switchCamera(camera);
              },
            );
          }).toList(),
        ),
      ),
    );
  }
}

class DetectionOverlayPainter extends CustomPainter {
  final List<dynamic> detections;

  DetectionOverlayPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    for (final detection in detections) {
      final bbox = detection['bbox'] as List<dynamic>?;
      final className = detection['class_name'] as String? ?? 'Unknown';
      final confidence = detection['confidence'] as double? ?? 0.0;
      
      if (bbox != null && bbox.length >= 4) {
        final paint = Paint()
          ..color = Colors.red
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke;

        final rect = Rect.fromLTRB(
          bbox[0].toDouble(),
          bbox[1].toDouble(),
          bbox[2].toDouble(),
          bbox[3].toDouble(),
        );

        canvas.drawRect(rect, paint);

        // Draw label
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$className ${(confidence * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );

        textPainter.layout();
        
        final labelRect = Rect.fromLTWH(
          rect.left,
          rect.top - textPainter.height - 4,
          textPainter.width + 8,
          textPainter.height + 4,
        );

        canvas.drawRect(labelRect, Paint()..color = Colors.red);
        textPainter.paint(canvas, Offset(rect.left + 4, rect.top - textPainter.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
