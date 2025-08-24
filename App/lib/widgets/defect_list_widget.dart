import 'package:flutter/material.dart';
import '../services/local_database_service.dart';

/// A reusable widget that shows the list of defects for a given board id.
/// This widget caches the Future so that the DB is not queried on every rebuild,
/// preventing a loading flicker when parent widgets rebuild frequently.
class DefectListWidget extends StatefulWidget {
  final int? boardId;
  final double height;

  /// A simple token that parents can bump to force the widget to reload
  /// its cached Future from the database. Increment this to refresh.
  final int reloadToken;

  const DefectListWidget({
    Key? key,
    required this.boardId,
    this.height = 220,
    this.reloadToken = 0,
  }) : super(key: key);

  @override
  State<DefectListWidget> createState() => _DefectListWidgetState();
}

class _DefectListWidgetState extends State<DefectListWidget> {
  Future<List<Map<String, dynamic>>>? _defectsFuture;
  final LocalDatabaseService _db = LocalDatabaseService();

  @override
  void initState() {
    super.initState();
    _prepareFuture();
  }

  @override
  void didUpdateWidget(covariant DefectListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recreate the future when board changes or when parent bumps the reloadToken
    if (oldWidget.boardId != widget.boardId ||
        oldWidget.reloadToken != widget.reloadToken) {
      _prepareFuture();
    }
  }

  void _prepareFuture() {
    if (widget.boardId == null) {
      _defectsFuture = null;
    } else {
      _defectsFuture = _db.getDefectsByBoard(widget.boardId!);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    if (_defectsFuture == null) {
      return Container(
        height: widget.height,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: const Center(child: Text('Chưa có bo được chọn')),
      );
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _defectsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final defects = snapshot.data;
        if (defects == null || defects.isEmpty) {
          return Container(
            height: widget.height,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: const Center(child: Text('Không tìm thấy lỗi nào')),
          );
        }

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300!, width: 1),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: defects.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final d = defects[index];
              final type = (d['type'] ?? '').toString();
              final judgement = (d['judgement'] ?? 'Chưa xác định').toString();
              final time = (d['time'] ?? '').toString();
              final coords = (d['coordinates'] ?? '').toString();

              return ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(_getDefectDisplayName(type)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Phán định: $judgement'),
                    if (time.isNotEmpty)
                      Text(
                        'Thời gian: $time',
                        style: const TextStyle(fontSize: 12),
                      ),
                    if (coords.isNotEmpty)
                      Text(
                        'Toạ độ: $coords',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
                trailing: Text('#${d['id_defect'] ?? (index + 1)}'),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(
                        'Chi tiết lỗi #${d['id_defect'] ?? (index + 1)}',
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Loại: ${_getDefectDisplayName(type)}'),
                          const SizedBox(height: 8),
                          Text('Phán định: $judgement'),
                          if (time.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Thời gian: $time'),
                          ],
                          if (coords.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('Toạ độ: $coords'),
                          ],
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Đóng'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
