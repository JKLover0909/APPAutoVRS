import 'package:flutter/material.dart';
import 'dart:typed_data';

class DetectionOverlayWidget extends StatelessWidget {
  final Uint8List imageData;
  final List<Map<String, dynamic>>? detections;
  final double width;
  final double height;

  const DetectionOverlayWidget({
    Key? key,
    required this.imageData,
    required this.detections,
    required this.width,
    required this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          // Base image
          Image.memory(
            imageData,
            fit: BoxFit.cover,
            width: width,
            height: height,
          ),
          // Detection overlay
          if (detections != null && detections!.isNotEmpty)
            CustomPaint(
              painter: DetectionPainter(detections: detections!),
              size: Size(width, height),
            ),
        ],
      ),
    );
  }
}

class DetectionPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;

  DetectionPainter({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final detection in detections) {
      try {
        // Parse detection coordinates - backend sends [x1, y1, x2, y2] format
        final bbox = detection['bbox'] as List?;
        final confidence = (detection['confidence'] as num?)?.toDouble() ?? 0.0;

        if (bbox != null && bbox.length >= 4) {
          final x1 = (bbox[0] as num).toDouble();
          final y1 = (bbox[1] as num).toDouble(); 
          final x2 = (bbox[2] as num).toDouble();
          final y2 = (bbox[3] as num).toDouble();

          // Assume coordinates are already in pixels, scale to widget size
          final rect = Rect.fromLTRB(
            x1,
            y1, 
            x2,
            y2,
          );

          // Draw bounding box
          canvas.drawRect(rect, paint);

          // Draw confidence text
          final textSpan = TextSpan(
            text: '${(confidence * 100).toStringAsFixed(1)}%',
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.white,
            ),
          );

          final textPainter = TextPainter(
            text: textSpan,
            textDirection: TextDirection.ltr,
          );

          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(rect.left, rect.top - 15),
          );

          debugPrint('🎯 Drawing bbox: x1=$x1, y1=$y1, x2=$x2, y2=$y2, conf=$confidence');
        } else {
          debugPrint('❌ Invalid bbox format: $bbox');
        }
      } catch (e) {
        debugPrint('❌ Error drawing detection: $e');
        debugPrint('❌ Detection data: $detection');
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
