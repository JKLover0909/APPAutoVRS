import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:go_router/go_router.dart';

class LightAdjustScreen extends StatefulWidget {
  const LightAdjustScreen({super.key});

  @override
  State<LightAdjustScreen> createState() => _LightAdjustScreenState();
}

class _LightAdjustScreenState extends State<LightAdjustScreen> {
  double _domeLight = 50.0;
  double _ringLight = 30.0;
  double _backLight = 70.0;
  double _sideLight = 40.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Preview Panel
          Expanded(
            flex: 3,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Xem trước hình ảnh',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Stack(
                          children: [
                            // Simulated camera feed with lighting effects
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    FeatherIcons.camera,
                                    size: 64,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Live Camera Preview',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Brightness: ${_calculateBrightness()}%',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Lighting effect overlay
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                gradient: RadialGradient(
                                  center: const Alignment(0, -0.3),
                                  radius: 1.2,
                                  colors: [
                                    Colors.white.withOpacity(_domeLight / 200),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Light Control Panel
          SizedBox(
            width: 320,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Điều chỉnh ánh sáng',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const Divider(height: 24),

                    // Light controls
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildLightControl(
                              'Đèn vòm',
                              _domeLight,
                              FeatherIcons.sun,
                              Colors.orange,
                              (value) => setState(() => _domeLight = value),
                            ),

                            const SizedBox(height: 24),

                            _buildLightControl(
                              'Đèn vòng',
                              _ringLight,
                              FeatherIcons.circle,
                              Colors.blue,
                              (value) => setState(() => _ringLight = value),
                            ),

                            const SizedBox(height: 24),

                            _buildLightControl(
                              'Đèn nền',
                              _backLight,
                              FeatherIcons.square,
                              Colors.green,
                              (value) => setState(() => _backLight = value),
                            ),

                            const SizedBox(height: 24),

                            _buildLightControl(
                              'Đèn bên',
                              _sideLight,
                              FeatherIcons.triangle,
                              Colors.purple,
                              (value) => setState(() => _sideLight = value),
                            ),

                            const SizedBox(height: 32),

                            // Preset buttons
                            const Text(
                              'Cài đặt sẵn',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _applyDefaultPreset,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Mặc định'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _applyBrightPreset,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Sáng'),
                                  ),
                                ),
                              ],
                            ),

                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _applyDarkPreset,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade800,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Tối'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: _resetAllLights,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade600,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Reset'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/manual-vrs'),
                            icon: const Icon(FeatherIcons.check, size: 18),
                            label: const Text('Hoàn tất'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildLightControl(
    String title,
    double value,
    IconData icon,
    Color color,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const Spacer(),
            Text(
              '${value.round()}%',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: color,
            thumbColor: color,
            overlayColor: color.withOpacity(0.3),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  int _calculateBrightness() {
    return ((_domeLight + _ringLight + _backLight + _sideLight) / 4).round();
  }

  void _applyDefaultPreset() {
    setState(() {
      _domeLight = 50.0;
      _ringLight = 30.0;
      _backLight = 70.0;
      _sideLight = 40.0;
    });
  }

  void _applyBrightPreset() {
    setState(() {
      _domeLight = 80.0;
      _ringLight = 70.0;
      _backLight = 90.0;
      _sideLight = 60.0;
    });
  }

  void _applyDarkPreset() {
    setState(() {
      _domeLight = 20.0;
      _ringLight = 10.0;
      _backLight = 30.0;
      _sideLight = 15.0;
    });
  }

  void _resetAllLights() {
    setState(() {
      _domeLight = 0.0;
      _ringLight = 0.0;
      _backLight = 0.0;
      _sideLight = 0.0;
    });
  }
}
