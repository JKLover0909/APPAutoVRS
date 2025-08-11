import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/statistics_provider.dart';

class NGRateScreen extends StatefulWidget {
  const NGRateScreen({super.key});

  @override
  State<NGRateScreen> createState() => _NGRateScreenState();
}

class _NGRateScreenState extends State<NGRateScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure data is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<StatisticsProvider>(context, listen: false);
      if (!provider.isLoading && provider.lotStatistics.isEmpty) {
        provider.initialize();
      }
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
              const Text(
                'Thống kê tỉ lệ phán định',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: Consumer<StatisticsProvider>(
                  builder: (context, statsProvider, child) {
                    if (statsProvider.isLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (statsProvider.lotStatistics.isEmpty) {
                      return const Center(
                        child: Text(
                          'Không có dữ liệu thống kê',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      );
                    }

                    return SingleChildScrollView(
                      child: DataTable(
                        columnSpacing: 40,
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey.shade100,
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Mã Lô (id_lot)',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Số lượng Bo',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Tỉ lệ NG',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Tỉ lệ lỗi giả',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                        rows: statsProvider.lotStatistics
                            .map(
                              (lot) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      lot['lotId'] as String,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text((lot['boardCount'] as int).toString())),
                                  DataCell(
                                    Text(
                                      '${(lot['ngRate'] as double).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        color: Colors.red.shade600,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text('${(lot['falsePositiveRate'] as double).toStringAsFixed(1)}%')),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
