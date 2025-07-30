import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DefectTypeScreen extends StatelessWidget {
  const DefectTypeScreen({super.key});

  final List<DefectData> _defectData = const [
    DefectData(type: 'Hở mạch', count: 12, color: Colors.red),
    DefectData(type: 'Thiếu linh kiện', count: 19, color: Colors.blue),
    DefectData(type: 'Nhiễu ảnh', count: 3, color: Colors.green),
    DefectData(type: 'Xước mạch', count: 8, color: Colors.orange),
  ];

  final List<DefectDetail> _defectDetails = const [
    DefectDetail(id: 'DEF-001', type: 'Hở mạch', judgment: 'NG'),
    DefectDetail(id: 'DEF-002', type: 'Thiếu linh kiện', judgment: 'NG'),
    DefectDetail(id: 'DEF-003', type: 'Xước mạch', judgment: 'NG'),
    DefectDetail(id: 'DEF-004', type: 'Nhiễu ảnh', judgment: 'OK'),
    DefectDetail(id: 'DEF-005', type: 'Hở mạch', judgment: 'NG'),
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
                'Thống kê loại lỗi cho Lô: LOT-A-452',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),

              const SizedBox(height: 24),

              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left side - Chart and Summary
                    Expanded(
                      flex: 1,
                      child: Column(
                        children: [
                          // Pie Chart
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                const Text(
                                  'Phân bố loại lỗi',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: PieChart(
                                    PieChartData(
                                      sections: _defectData.map((data) {
                                        final percentage =
                                            (data.count /
                                                _defectData.fold<int>(
                                                  0,
                                                  (sum, item) =>
                                                      sum + item.count,
                                                )) *
                                            100;
                                        return PieChartSectionData(
                                          color: data.color,
                                          value: data.count.toDouble(),
                                          title:
                                              '${percentage.toStringAsFixed(1)}%',
                                          radius: 60,
                                          titleStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        );
                                      }).toList(),
                                      centerSpaceRadius: 40,
                                      sectionsSpace: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Summary Table
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bảng tổng hợp lỗi',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      columnSpacing: 20,
                                      headingRowColor:
                                          WidgetStateProperty.all(
                                            Colors.grey.shade100,
                                          ),
                                      columns: const [
                                        DataColumn(
                                          label: Text(
                                            'Loại lỗi',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Text(
                                            'Số lượng',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: _defectData
                                          .map(
                                            (data) => DataRow(
                                              cells: [
                                                DataCell(
                                                  Row(
                                                    children: [
                                                      Container(
                                                        width: 16,
                                                        height: 16,
                                                        decoration: BoxDecoration(
                                                          color: data.color,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                2,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          data.type,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    data.count.toString(),
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      fontSize: 12,
                                                    ),
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
                        ],
                      ),
                    ),

                    const SizedBox(width: 24),

                    // Right side - Details List
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Danh sách chi tiết',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: [
                                  // Header
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(8),
                                        topRight: Radius.circular(8),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'ID Bất thường',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text(
                                            'Loại lỗi',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: Text(
                                            'Phán định',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Data rows
                                  Expanded(
                                    child: ListView.builder(
                                      itemCount: _defectDetails.length,
                                      itemBuilder: (context, index) {
                                        final detail = _defectDetails[index];
                                        return Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade200,
                                                width: 1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 1,
                                                child: Text(detail.id),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Text(detail.type),
                                              ),
                                              Expanded(
                                                flex: 1,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color:
                                                        detail.judgment == 'NG'
                                                        ? Colors.red.shade100
                                                        : Colors.green.shade100,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    detail.judgment,
                                                    style: TextStyle(
                                                      color:
                                                          detail.judgment ==
                                                              'NG'
                                                          ? Colors.red.shade700
                                                          : Colors
                                                                .green
                                                                .shade700,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DefectData {
  final String type;
  final int count;
  final Color color;

  const DefectData({
    required this.type,
    required this.count,
    required this.color,
  });
}

class DefectDetail {
  final String id;
  final String type;
  final String judgment;

  const DefectDetail({
    required this.id,
    required this.type,
    required this.judgment,
  });
}
