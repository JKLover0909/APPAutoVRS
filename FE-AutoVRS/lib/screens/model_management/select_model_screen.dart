import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';

class SelectModelScreen extends StatefulWidget {
  const SelectModelScreen({super.key});

  @override
  State<SelectModelScreen> createState() => _SelectModelScreenState();
}

class _SelectModelScreenState extends State<SelectModelScreen> {
  final TextEditingController _searchController = TextEditingController();

  final List<ModelData> _models = [
    ModelData(id: 'MODEL-001', lineSize: '0.125', spaceSize: '0.150'),
    ModelData(id: 'MODEL-002', lineSize: '0.100', spaceSize: '0.130'),
    ModelData(id: 'MODEL-003', lineSize: '0.200', spaceSize: '0.180'),
  ];

  List<ModelData> _filteredModels = [];

  @override
  void initState() {
    super.initState();
    _filteredModels = _models;
    _searchController.addListener(_filterModels);
  }

  void _filterModels() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredModels = _models
          .where((model) => model.id.toLowerCase().contains(query))
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

              // Table
              Expanded(
                child: SingleChildScrollView(
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
                                  model.id,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              DataCell(Text(model.lineSize)),
                              DataCell(Text(model.spaceSize)),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectModel(ModelData model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận lựa chọn'),
        content: Text('Bạn có chắc chắn muốn sử dụng bộ tham số ${model.id}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Đã chọn Model ${model.id} thành công!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class ModelData {
  final String id;
  final String lineSize;
  final String spaceSize;

  ModelData({
    required this.id,
    required this.lineSize,
    required this.spaceSize,
  });
}
