import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/vrs_provider.dart';
import '../../services/local_database_service.dart';
import '../../main.dart';

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
  String? _selectedModelId; // Track the currently selected model

  @override
  void initState() {
    super.initState();
    _loadModels();
    _searchController.addListener(_filterModels);
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbService = LocalDatabaseService();
      final models = await dbService.getAllModels();

      // Get current model from provider to highlight it
      final vrsProvider = Provider.of<VRSProvider>(context, listen: false);
      final currentModelId = vrsProvider.currentModel;

      setState(() {
        _models = models;
        _filteredModels = models;
        _selectedModelId = currentModelId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('Lỗi tải dữ liệu: $e')),
        );
      }
    }
  }

  void _filterModels() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredModels = _models.where((model) {
        final idModelStr = model['id_model']?.toString().toLowerCase() ?? '';
        return idModelStr.contains(query);
      }).toList();
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
                  Row(
                    children: [
                      // ✅ Nút Refresh
                      IconButton(
                        onPressed: _isLoading ? null : _loadModels,
                        icon: const Icon(FeatherIcons.refreshCw),
                        tooltip: 'Làm mới danh sách',
                        color: Colors.blue.shade600,
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () async {
                          // ✅ Đợi quay lại từ màn hình Add Model
                          await context.push('/add-model');
                          // ✅ Refresh danh sách sau khi quay lại
                          if (mounted) {
                            _loadModels();
                          }
                        },
                        icon: const Icon(FeatherIcons.plus, size: 18),
                        label: const Text('Thêm mã hàng mới'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
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
          Icon(FeatherIcons.package, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Chưa có mã hàng nào',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy thêm mã hàng mới để bắt đầu',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              // ✅ Đợi quay lại từ màn hình Add Model
              await context.push('/add-model');
              // ✅ Refresh danh sách sau khi quay lại
              if (mounted) {
                _loadModels();
              }
            },
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
              'Mã hàng ',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          DataColumn(
            label: Text('Tên', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          DataColumn(
            label: Text(
              'Kích thước Line',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          DataColumn(
            label: Text(
              'Kích thước Space',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          DataColumn(
            label: Text(
              'Thao tác',
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
                      model['id_model']?.toString() ?? 'Unknown',
                      style: TextStyle(
                        fontWeight:
                            model['id_model']?.toString() == _selectedModelId
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: model['id_model']?.toString() == _selectedModelId
                            ? Colors.blue
                            : Colors.black,
                      ),
                    ),
                  ),
                  DataCell(Text(model['name']?.toString() ?? 'N/A')),
                  DataCell(Text(model['line_size']?.toString() ?? 'N/A')),
                  DataCell(Text(model['space_size']?.toString() ?? 'N/A')),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          onPressed:
                              model['id_model']?.toString() == _selectedModelId
                              ? null
                              : () => _selectModel(model),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                model['id_model']?.toString() ==
                                    _selectedModelId
                                ? Colors.grey.shade400
                                : Colors.green.shade500,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            model['id_model']?.toString() == _selectedModelId
                                ? 'Đang chọn'
                                : 'Chọn',
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Xóa',
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _onDeleteModel(model),
                        ),
                      ],
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
    // Hiển thị dialog xác nhận
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận lựa chọn'),
        content: Text(
          'Bạn có chắc chắn muốn sử dụng bộ tham số ${model['id_model'].toString()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Cập nhật model trong Provider
      final vrsProvider = Provider.of<VRSProvider>(context, listen: false);

      // Capture router before async gaps to avoid using context after await
      final router = GoRouter.of(context);

      await vrsProvider.setCurrentModel(model['id_model'].toString());

      // Update selected model ID for UI highlighting
      setState(() {
        _selectedModelId = model['id_model'].toString();
      });

      // Hiển thị SnackBar **trước khi pop màn hình** using global messenger
      final snackBar = SnackBar(
        content: Text(
          'Đã chọn Model ${model['id_model'].toString()} thành công!',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      );

      final messengerState = scaffoldMessengerKey.currentState;
      if (messengerState != null && messengerState.mounted) {
        messengerState.showSnackBar(snackBar);
      } else {
        // If the messenger isn't ready (rare), schedule the SnackBar for the next frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scaffoldMessengerKey.currentState?.showSnackBar(snackBar);
        });
      }

      // Delay một chút để người dùng nhìn thấy SnackBar
      await Future.delayed(const Duration(milliseconds: 300));

      // Quay lại màn hình trước nếu có thể (use captured router)
      if (router.canPop()) {
        router.pop();
      }
    } catch (e) {
      // Hiển thị lỗi nếu có using global messenger
      if (mounted) {
        final messengerState = scaffoldMessengerKey.currentState;
        if (messengerState != null && messengerState.mounted) {
          messengerState.showSnackBar(
            SnackBar(
              content: Text('Lỗi cập nhật model: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: Text('Lỗi cập nhật model: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          });
        }
      }
    }
  }

  Future<void> _onDeleteModel(Map<String, dynamic> model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc chắn muốn xóa mã hàng ${model['id_model']} không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final db = LocalDatabaseService();
      final id = model['id_model'];
      if (id is int) {
        final deleted = await db.deleteModel(id);
        if (deleted > 0) {
          await _loadModels();
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Xóa thành công mã hàng $id'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Không tìm thấy mã hàng để xóa'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(
            content: Text('ID mã hàng không hợp lệ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Lỗi khi xóa: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
