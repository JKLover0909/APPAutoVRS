import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/video_frame_service.dart';

/// Widget hiển thị video frame từ Python streaming server
/// Có thể được sử dụng trong ManualVRS và AutoVRS screens
class VideoFrameWidget extends StatefulWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? placeholder;
  final Color backgroundColor;
  final bool showControls;
  final bool showStats;
  final VoidCallback? onTap;

  const VideoFrameWidget({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.backgroundColor = Colors.black12,
    this.showControls = false,
    this.showStats = false,
    this.onTap,
  });

  @override
  State<VideoFrameWidget> createState() => _VideoFrameWidgetState();
}

class _VideoFrameWidgetState extends State<VideoFrameWidget> {
  late VideoFrameService _videoService;

  @override
  void initState() {
    super.initState();
    _videoService = VideoFrameService();

    // Auto-connect nếu chưa connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_videoService.isConnected) {
        _videoService.connect();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _videoService,
      child: Consumer<VideoFrameService>(
        builder: (context, videoService, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: videoService.isConnected
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.red.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Stack(
              children: [
                // Video frame chính
                _buildVideoContent(videoService),

                // Controls overlay (nếu enable)
                if (widget.showControls) _buildControlsOverlay(videoService),

                // Stats overlay (nếu enable)
                if (widget.showStats) _buildStatsOverlay(videoService),

                // Connection status indicator
                _buildConnectionIndicator(videoService),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Xây dựng nội dung video chính
  Widget _buildVideoContent(VideoFrameService videoService) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: videoService.hasFrame
            ? Image.memory(
                videoService.currentFrame!,
                width: widget.width,
                height: widget.height,
                fit: widget.fit,
                gaplessPlayback: true, // Smooth frame transitions
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder('Lỗi hiển thị frame');
                },
              )
            : _buildPlaceholder(
                videoService.isConnected
                    ? 'Đang chờ video frame...'
                    : widget.placeholder ?? 'Không có kết nối video',
              ),
      ),
    );
  }

  /// Xây dựng placeholder khi không có frame
  Widget _buildPlaceholder(String message) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.backgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Xây dựng controls overlay
  Widget _buildControlsOverlay(VideoFrameService videoService) {
    return Positioned(
      bottom: 8,
      left: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // Connection toggle button
            IconButton(
              icon: Icon(
                videoService.isConnected ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () {
                if (videoService.isConnected) {
                  videoService.disconnect();
                } else {
                  videoService.connect();
                }
              },
            ),

            const SizedBox(width: 8),

            // Frame info
            Expanded(
              child: Text(
                'Frame: ${videoService.frameId} | ${videoService.videoWidth}x${videoService.videoHeight}',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),

            // Settings button
            IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 20),
              onPressed: () => _showSettingsDialog(context, videoService),
            ),
          ],
        ),
      ),
    );
  }

  /// Xây dựng stats overlay
  Widget _buildStatsOverlay(VideoFrameService videoService) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'FPS: ${videoService.videoFps.toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              'Frames: ${videoService.framesReceived}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            Text(
              'Size: ${videoService.videoWidth}x${videoService.videoHeight}',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  /// Xây dựng connection status indicator
  Widget _buildConnectionIndicator(VideoFrameService videoService) {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: videoService.isConnected ? Colors.green : Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              videoService.isConnected ? 'LIVE' : 'OFFLINE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hiển thị dialog settings
  void _showSettingsDialog(
    BuildContext context,
    VideoFrameService videoService,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Stream Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Server: ws://localhost:8081'),
            const SizedBox(height: 8),
            Text(
              'Status: ${videoService.isConnected ? "Connected" : "Disconnected"}',
            ),
            const SizedBox(height: 8),
            Text(
              'Resolution: ${videoService.videoWidth}x${videoService.videoHeight}',
            ),
            const SizedBox(height: 8),
            Text('FPS: ${videoService.videoFps}'),
            const SizedBox(height: 8),
            Text('Frames Received: ${videoService.framesReceived}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              videoService.disconnect();
              Navigator.of(context).pop();
            },
            child: const Text('Disconnect'),
          ),
          TextButton(
            onPressed: () {
              videoService.connect();
              Navigator.of(context).pop();
            },
            child: const Text('Reconnect'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
