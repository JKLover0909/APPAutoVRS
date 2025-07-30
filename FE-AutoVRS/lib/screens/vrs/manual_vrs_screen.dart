import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';

class ManualVRSScreen extends StatefulWidget {
  const ManualVRSScreen({super.key});

  @override
  State<ManualVRSScreen> createState() => _ManualVRSScreenState();
}

class _ManualVRSScreenState extends State<ManualVRSScreen> {
  double _magnification = 140;
  int _currentBoard = 4;
  final int _totalBoards = 25;

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
                              const Text(
                                'Ảnh Live từ VRS',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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
                                      left: 120,
                                      top: 100,
                                      child: Container(
                                        width: 100,
                                        height: 50,
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
                                            left: 50,
                                            top: 40,
                                            child: Container(
                                              width: 35,
                                              height: 15,
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
                                            left: 50,
                                            top: 40,
                                            child: Container(
                                              width: 35,
                                              height: 15,
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

          // Info & Action Panel
          SizedBox(
            width: 320,
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
                    _buildInfoRow('Mã Lô:', 'LOT-C-789'),
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
                          min: 30,
                          max: 250,
                          divisions: 220,
                          onChanged: (value) =>
                              setState(() => _magnification = value),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Tools Section
                    const Text(
                      'Công cụ Định vị',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/board-align/1'),
                            icon: const Icon(FeatherIcons.move, size: 16),
                            label: const Text('Vị trí Bo'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyan.shade500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/light-adjust'),
                            icon: const Icon(FeatherIcons.sun, size: 16),
                            label: const Text('Ánh sáng'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade500,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Judgment Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _makeJudgment(true),
                            icon: const Icon(FeatherIcons.check, size: 20),
                            label: const Text(
                              'OK',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _makeJudgment(false),
                            icon: const Icon(FeatherIcons.x, size: 20),
                            label: const Text(
                              'NG',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
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
        content: Text('Đã phán định: $result cho Bo $_currentBoard'),
        backgroundColor: isOK ? Colors.green : Colors.red,
      ),
    );

    // Auto move to next board
    if (_currentBoard < _totalBoards) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        _nextBoard();
      });
    }
  }
}
