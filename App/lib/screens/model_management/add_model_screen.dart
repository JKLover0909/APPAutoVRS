import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';

class AddModelScreen extends StatefulWidget {
  const AddModelScreen({super.key});

  @override
  State<AddModelScreen> createState() => _AddModelScreenState();
}

class _AddModelScreenState extends State<AddModelScreen> {
  final _formKey = GlobalKey<FormState>();
  final _modelIdController = TextEditingController();
  final _lineSizeController = TextEditingController();
  final _spaceSizeController = TextEditingController();

  String? _selectedFile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Thêm mã hàng mới',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 32),

                  // Model ID
                  TextFormField(
                    controller: _modelIdController,
                    decoration: const InputDecoration(
                      labelText: 'Mã hàng (id_model)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập mã hàng';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Line Size
                  TextFormField(
                    controller: _lineSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Kích thước đường mạch (line_size)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập kích thước đường mạch';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Vui lòng nhập số hợp lệ';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // Space Size
                  TextFormField(
                    controller: _spaceSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Kích thước khoảng trống (space_size)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng nhập kích thước khoảng trống';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Vui lòng nhập số hợp lệ';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  // File Upload
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Đường dẫn file Gerber (url_gerber)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey.shade300,
                            style: BorderStyle.solid,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: _selectFile,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                FeatherIcons.fileText,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _selectedFile ?? 'Tải tệp lên hoặc kéo và thả',
                                style: TextStyle(
                                  color: _selectedFile != null
                                      ? Colors.blue.shade600
                                      : Colors.grey.shade600,
                                  fontWeight: _selectedFile != null
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                              if (_selectedFile == null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Chọn file Gerber (.gbr, .zip)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Hủy'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _saveModel,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Lưu'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectFile() {
    // Simulation of file selection
    setState(() {
      _selectedFile = 'example_gerber_file.gbr';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Chức năng tải file sẽ được triển khai sau'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _saveModel() {
    if (_formKey.currentState!.validate()) {
      // Simulate saving model
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã lưu model ${_modelIdController.text} thành công!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      context.pop();
    }
  }

  @override
  void dispose() {
    _modelIdController.dispose();
    _lineSizeController.dispose();
    _spaceSizeController.dispose();
    super.dispose();
  }
}
