import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String selectedRange = "Day";
  String selectedDate = "2025-09-02";

  // Dynamic date options based on selected range
  List<String> get dateOptions {
    switch (selectedRange) {
      case "Year":
        return ["2025", "2024", "2023", "2022", "2021"];
      case "Month":
        return ["September 2025", "August 2025", "July 2025", "June 2025"];
      case "Week":
        return [
          "Week 36, 2025",
          "Week 35, 2025",
          "Week 34, 2025",
          "Week 33, 2025",
        ];
      case "Day":
      default:
        return ["2025-09-02", "2025-09-01", "2025-08-31", "2025-08-30"];
    }
  }

  // Get chart data based on selected range
  List<FlSpot> get chartData {
    switch (selectedRange) {
      case "Year":
        return const [
          FlSpot(0, 25),
          FlSpot(1, 28),
          FlSpot(2, 32),
          FlSpot(3, 29),
          FlSpot(4, 35),
          FlSpot(5, 31),
          FlSpot(6, 38),
          FlSpot(7, 34),
          FlSpot(8, 40),
          FlSpot(9, 36),
          FlSpot(10, 42),
          FlSpot(11, 39),
        ];
      case "Month":
        return const [
          FlSpot(0, 28),
          FlSpot(1, 32),
          FlSpot(2, 25),
          FlSpot(3, 38),
          FlSpot(4, 35),
          FlSpot(5, 42),
          FlSpot(6, 30),
          FlSpot(7, 45),
          FlSpot(8, 38),
          FlSpot(9, 40),
          FlSpot(10, 36),
          FlSpot(11, 43),
          FlSpot(12, 39),
          FlSpot(13, 41),
          FlSpot(14, 37),
        ];
      case "Week":
        return const [
          FlSpot(0, 30),
          FlSpot(1, 35),
          FlSpot(2, 28),
          FlSpot(3, 42),
          FlSpot(4, 38),
          FlSpot(5, 45),
          FlSpot(6, 40),
        ];
      case "Day":
      default:
        return const [
          FlSpot(0, 20),
          FlSpot(1, 25),
          FlSpot(2, 18),
          FlSpot(3, 32),
          FlSpot(4, 28),
          FlSpot(5, 36),
          FlSpot(6, 30),
          FlSpot(7, 24),
          FlSpot(8, 38),
          FlSpot(9, 33),
          FlSpot(10, 29),
          FlSpot(11, 35),
        ];
    }
  }

  // Get bottom titles for chart
  String getBottomTitle(double value) {
    switch (selectedRange) {
      case "Year":
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return value.toInt() < months.length ? months[value.toInt()] : '';
      case "Month":
        return '${value.toInt() + 1}';
      case "Week":
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return value.toInt() < days.length ? days[value.toInt()] : '';
      case "Day":
      default:
        return '${value.toInt()}:00';
    }
  }

  void _updateDateForRange() {
    List<String> options = dateOptions;
    if (!options.contains(selectedDate)) {
      selectedDate = options.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "History",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Row(
                  //   children: [
                  //     Container(
                  //       decoration: BoxDecoration(
                  //         color: Colors.white.withOpacity(0.2),
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //       child: IconButton(
                  //         onPressed: () {},
                  //         icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  //         iconSize: 22,
                  //       ),
                  //     ),
                  //     const SizedBox(width: 8),
                  //     Container(
                  //       decoration: BoxDecoration(
                  //         color: Colors.white.withOpacity(0.2),
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //       child: IconButton(
                  //         onPressed: () {},
                  //         icon: const Icon(Icons.menu, color: Colors.white),
                  //         iconSize: 22,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),

            // Main content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Text(
                      'Speed History',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Time Range Selector
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: ["Day", "Week", "Month", "Year"]
                            .map(
                              (e) => Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedRange = e;
                                      _updateDateForRange();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: selectedRange == e
                                          ? Colors.blue
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      e,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: selectedRange == e
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        color: selectedRange == e
                                            ? Colors.white
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Chart Container
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Chart Header
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "${selectedRange}ly Speed Analysis",
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedDate,
                                        isDense: true,
                                        items: dateOptions
                                            .map(
                                              (date) => DropdownMenuItem(
                                                value: date,
                                                child: Text(
                                                  date,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.grey[700],
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (value) {
                                          setState(() => selectedDate = value!);
                                        },
                                        icon: Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Colors.grey[600],
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              // Line Chart
                              Expanded(
                                child: LineChart(
                                  LineChartData(
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: true,
                                      drawHorizontalLine: true,
                                      horizontalInterval: 5,
                                      verticalInterval: 1,
                                      getDrawingHorizontalLine: (value) =>
                                          FlLine(
                                            color: Colors.grey[200]!,
                                            strokeWidth: 1,
                                          ),
                                      getDrawingVerticalLine: (value) => FlLine(
                                        color: Colors.grey[200]!,
                                        strokeWidth: 1,
                                      ),
                                    ),
                                    titlesData: FlTitlesData(
                                      show: true,
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 44,
                                          interval: 10,
                                          getTitlesWidget: (value, meta) =>
                                              Text(
                                                '${value.toInt()}',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                        ),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 32,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) =>
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Text(
                                                  getBottomTitle(value),
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                ),
                                              ),
                                        ),
                                      ),
                                      rightTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                      topTitles: const AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: false,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: Border(
                                        left: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                        bottom: BorderSide(
                                          color: Colors.grey[300]!,
                                        ),
                                      ),
                                    ),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: chartData,
                                        isCurved: true,
                                        curveSmoothness: 0.3,
                                        color: Colors.blue,
                                        barWidth: 3,
                                        dotData: FlDotData(
                                          show: true,
                                          getDotPainter:
                                              (spot, percent, barData, index) =>
                                                  FlDotCirclePainter(
                                                    radius: 4,
                                                    color: Colors.white,
                                                    strokeWidth: 2,
                                                    strokeColor: Colors.blue,
                                                  ),
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.blue.withOpacity(0.15),
                                              Colors.blue.withOpacity(0.0),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    lineTouchData: LineTouchData(
                                      enabled: true,
                                      touchTooltipData: LineTouchTooltipData(
                                        getTooltipItems: (touchedSpots) {
                                          return touchedSpots.map((spot) {
                                            return LineTooltipItem(
                                              '${spot.y.toInt()} km/h',
                                              GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                            );
                                          }).toList();
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 32),

                              // Statistics Row
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStat(
                                      "Average",
                                      "32 km/h",
                                      Icons.timeline,
                                    ),
                                    _buildStat(
                                      "Maximum",
                                      "45 km/h",
                                      Icons.keyboard_arrow_up,
                                    ),
                                    _buildStat(
                                      "Minimum",
                                      "18 km/h",
                                      Icons.keyboard_arrow_down,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
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
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
      ],
    );
  }
}
