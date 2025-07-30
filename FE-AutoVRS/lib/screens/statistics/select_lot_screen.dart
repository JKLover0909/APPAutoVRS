import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SelectLotScreen extends StatelessWidget {
  const SelectLotScreen({super.key});

  final List<String> _lots = const [
    'LOT-A-452',
    'LOT-B-453',
    'LOT-C-454',
    'LOT-D-455',
    'LOT-E-456',
  ];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Chọn lô hàng để xem thống kê lỗi',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 24),

                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _lots.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final lot = _lots[index];
                      return Card(
                        elevation: 2,
                        child: ListTile(
                          title: Text(
                            lot,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () => context.push('/defect-type'),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
