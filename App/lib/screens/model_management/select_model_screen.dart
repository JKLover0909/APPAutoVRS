import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/vrs_provider.dart';
import '../../services/local_database_service.dart';

class SelectModelScreen extends StatefulWidget {
  const SelectModelScreen({super.key});

  @override
  State<SelectModelScreen> createState() => _SelectModelScreenState();
}

class _SelectModelScreenState extends State<SelectModelScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _filteredModels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModels();
    _searchController.addListener(_filterModels);
  }

  Future<void> _loadModels() async {
    try {
      final dbService = LocalDatabaseService();
      final models = await dbService.getAllModels();
      setState(() {
        _models = models;
        _filteredModels = models;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  void _filterModels() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredModels = _models
          .where((model) => 
              (model['model_id'] ?? '').toLowerCase().contains(query))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chọn bộ tham số mã hàng',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/add-model'),
                    icon: const Icon(FeatherIcons.plus, size: 18),
                    label: const Text('Thêm mã hàng mới'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Search
              TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Tìm kiếm mã hàng...',
                  prefixIcon: Icon(FeatherIcons.search),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _models.isEmpty
                        ? _buildEmptyState()
                        : _buildModelTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FeatherIcons.package,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có mã hàng nào',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy thêm mã hàng mới để bắt đầu',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/add-model'),
            icon: const Icon(FeatherIcons.plus, size: 18),
            label: const Text('Thêm mã hàng mới'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelTable() {
    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 40,
        columns: const [
          DataColumn(
            label: Text(
              'Mã hàng (id_model)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          DataColumn(
            label: Text(
              'Kích thước đường mạch',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          DataColumn(
            label: Text(
              'Kích thước khoảng trống',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          DataColumn(
            label: Text(
              'Hành động',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
        rows: _filteredModels
            .map(
              (model) => DataRow(
                cells: [
                  DataCell(
                    Text(
                      model['model_id'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  DataCell(Text(model['line_size']?.toString() ?? 'N/A')),
                  DataCell(Text(model['space_size']?.toString() ?? 'N/A')),
                  DataCell(
                    ElevatedButton(
                      onPressed: () => _selectModel(model),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade500,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Chọn'),
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }

  void _selectModel(Map<String, dynamic> model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận lựa chọn'),
        content: Text('Bạn có chắc chắn muốn sử dụng bộ tham số ${model['model_id']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        // Update VRS Provider with selected model
        final vrsProvider = Provider.of<VRSProvider>(context, listen: false);
        await vrsProvider.setCurrentModel(model['model_id']);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã chọn Model ${model['model_id']} thành công!'),
              backgroundColor: Colors.green,
            ),
          );
          context.pop(); // Go back to previous screen
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi cập nhật model: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
