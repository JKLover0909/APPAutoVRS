import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/qcamber_gerber_service.dart';

/// Widget hiển thị ảnh Gerber từ QCamber
///
/// Dùng trong Manual VRS Screen để hiển thị:
/// - Ảnh Gerber tại tọa độ defect được chọn
/// - Loading state khi đang fetch ảnh
/// - Error message nếu có lỗi
/// - Placeholder nếu chưa chọn defect hoặc chưa có ảnh
class GerberImageWidget extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;

  const GerberImageWidget({
    super.key,
    required this.isLoading,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<QCamberGerberService>(
      builder: (context, gerberService, child) {
        // Loading state
        if (isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Đang tải ảnh Gerber...'),
                const SizedBox(height: 8),
                if (gerberService.lastMetadata != null)
                  Flexible(
                    child: Text(
                      'Model: ${gerberService.lastMetadata!['modelName']}',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          );
        }

        // Error state
        if (errorMessage != null || gerberService.lastError != null) {
          final errorText = errorMessage ?? gerberService.lastError ?? 'Có lỗi xảy ra';
          
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Lỗi',
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  // ✅ Wrap trong Container với maxHeight để tránh overflow
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          errorText,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 10,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Image state
        if (gerberService.hasImage && gerberService.gerberImage != null) {
          return Stack(
            children: [
              // Ảnh Gerber
              Image.memory(
                gerberService.gerberImage!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          size: 48,
                          color: Colors.orange,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Không thể hiển thị ảnh',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Metadata overlay
              if (gerberService.lastMetadata != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Model: ${gerberService.lastMetadata!['modelName']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Layer: ${gerberService.lastMetadata!['layerName']}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Tọa độ: (${gerberService.lastMetadata!['x']}, ${gerberService.lastMetadata!['y']})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        if (gerberService.lastMetadata!['defectType'] != null)
                          Text(
                            'Lỗi: ${gerberService.lastMetadata!['defectType']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }

        // Empty state - chưa chọn defect hoặc chưa tải ảnh
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Gerber View',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              Text(
                'Chọn lỗi để xem ảnh',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[400]),
              ),
            ],
          ),
        );
      },
    );
  }
}
