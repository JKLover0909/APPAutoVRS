import 'package:flutter/material.dart';

class NGRateScreen extends StatelessWidget {
  const NGRateScreen({super.key});

  final List<LotStatistics> _lotData = const [
    LotStatistics(
      lotId: 'LOT-A-452',
      boardCount: 500,
      ngRate: 5.2,
      falsePositiveRate: 0.8,
    ),
    LotStatistics(
      lotId: 'LOT-B-453',
      boardCount: 750,
      ngRate: 3.1,
      falsePositiveRate: 0.5,
    ),
    LotStatistics(
      lotId: 'LOT-C-454',
      boardCount: 320,
      ngRate: 7.8,
      falsePositiveRate: 1.2,
    ),
  ];

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
                child: SingleChildScrollView(
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
                    rows: _lotData
                        .map(
                          (lot) => DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  lot.lotId,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              DataCell(Text(lot.boardCount.toString())),
                              DataCell(
                                Text(
                                  '${lot.ngRate}%',
                                  style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              DataCell(Text('${lot.falsePositiveRate}%')),
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
}

class LotStatistics {
  final String lotId;
  final int boardCount;
  final double ngRate;
  final double falsePositiveRate;

  const LotStatistics({
    required this.lotId,
    required this.boardCount,
    required this.ngRate,
    required this.falsePositiveRate,
  });
}
