import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BoardAlignScreen extends StatefulWidget {
  final int step;

  const BoardAlignScreen({super.key, required this.step});

  @override
  State<BoardAlignScreen> createState() => _BoardAlignScreenState();
}

class _BoardAlignScreenState extends State<BoardAlignScreen> {
  double _zoomLevel = 1.0;
  final List<Offset> _selectedPoints = [];
  static final Map<int, Offset> _allPoints = {};

  @override
  Widget build(BuildContext context) {
    final stepTitles = {
      1: 'Bước 1/4: Chọn điểm A trên ảnh Camera',
      2: 'Bước 2/4: Chọn điểm B trên ảnh Camera',
      3: 'Bước 3/4: Chọn điểm C (tương ứng A) trên ảnh Thiết kế',
      4: 'Bước 4/4: Chọn điểm D (tương ứng B) trên ảnh Thiết kế',
    };

    final imageTexts = {
      1: 'Camera Feed',
      2: 'Camera Feed',
      3: 'Design File',
      4: 'Design File',
    };

    final imageColors = {
      1: Colors.grey.shade800,
      2: Colors.grey.shade800,
      3: Colors.grey.shade600,
      4: Colors.grey.shade600,
    };

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Title
              Text(
                stepTitles[widget.step] ?? 'Định vị',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Image Container
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: imageColors[widget.step],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: GestureDetector(
                    onTapDown: (details) => _onImageTap(details),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Transform.scale(
                        scale: _zoomLevel,
                        child: Stack(
                          children: [
                            // Background image simulation
                            Center(
                              child: Text(
                                imageTexts[widget.step] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Show previous points for reference
                            ..._buildPreviousPoints(),

                            // Show current selection
                            ..._selectedPoints.asMap().entries.map((entry) {
                              return _buildPointMarker(
                                entry.value,
                                _getPointLabel(widget.step, entry.key),
                                _getPointColor(widget.step),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Controls
              Row(
                children: [
                  // Zoom Control
                  Expanded(
                    child: Column(
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
                              '${_zoomLevel.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          value: _zoomLevel,
                          min: 1.0,
                          max: 5.0,
                          divisions: 40,
                          onChanged: (value) =>
                              setState(() => _zoomLevel = value),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Action Buttons
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => context.push('/manual-vrs'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade500,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Hủy'),
                      ),

                      if (widget.step == 4) ...[
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _allPoints.length >= 4
                              ? _finishAlignment
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Hoàn tất'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPreviousPoints() {
    List<Widget> points = [];

    // Show previous step points for reference
    if (widget.step >= 2 && _allPoints.containsKey(1)) {
      points.add(_buildPointMarker(_allPoints[1]!, 'A', Colors.blue));
    }
    if (widget.step >= 3 && _allPoints.containsKey(2)) {
      points.add(_buildPointMarker(_allPoints[2]!, 'B', Colors.blue));
    }
    if (widget.step >= 4 && _allPoints.containsKey(3)) {
      points.add(_buildPointMarker(_allPoints[3]!, 'C', Colors.yellow));
    }

    return points;
  }

  Widget _buildPointMarker(Offset position, String label, Color color) {
    return Positioned(
      left: position.dx - 10,
      top: position.dy - 10,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color.withOpacity(0.8),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  String _getPointLabel(int step, int index) {
    switch (step) {
      case 1:
        return 'A';
      case 2:
        return 'B';
      case 3:
        return 'C';
      case 4:
        return 'D';
      default:
        return '?';
    }
  }

  Color _getPointColor(int step) {
    return step <= 2 ? Colors.blue : Colors.yellow;
  }

  void _onImageTap(TapDownDetails details) {
    final localPosition = details.localPosition;

    // Only allow one point per step
    setState(() {
      _selectedPoints.clear();
      _selectedPoints.add(localPosition);
      _allPoints[widget.step] = localPosition;
    });

    // Auto-advance to next step (except for step 4)
    if (widget.step < 4) {
      Future.delayed(const Duration(milliseconds: 500), () {
        context.pushReplacement('/board-align/${widget.step + 1}');
      });
    }
  }

  void _finishAlignment() {
    // Show completion dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Định vị hoàn tất'),
        content: const Text(
          'Đã xác nhận định vị thành công!\nCác điểm đã được lưu.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/manual-vrs');
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
