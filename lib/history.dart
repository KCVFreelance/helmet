import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_database/firebase_database.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String selectedRange = "Day";
  String selectedDate = ""; // a label depending on range
  List<String> dateOptions = [];

  // Raw parsed data from Firebase
  // hourlyData[date][hour] = speed
  final Map<DateTime, Map<int, double>> hourlyData = {};
  // daily speeds aggregated (list of speeds per date)
  final Map<DateTime, List<double>> dailySpeeds = {};

  List<FlSpot> chartData = [];
  bool isLoading = true;

  double avgSpeed = 0.0;
  double maxSpeed = 0.0;
  double minSpeed = 0.0;

  final List<String> monthNames = const [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _loadAndPrepareData();
  }

  Future<void> _loadAndPrepareData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final coordsRef = FirebaseDatabase.instance.ref("1-000/coordinates");
      final snapshot = await coordsRef.get();

      hourlyData.clear();
      dailySpeeds.clear();

      if (snapshot.exists) {
        for (final dateNode in snapshot.children) {
          final key = dateNode.key;
          if (key == null) continue;

          final dt = _parseDateKey(key); // dd-MM-yyyy
          if (dt == null) continue;

          final Map<int, double> hours = {};
          final List<double> daySpeedList = [];

          for (final timeNode in dateNode.children) {
            final timeKey = timeNode.key;
            if (timeKey == null) continue;

            // skip latitude & longitude nodes
            if (timeKey.toLowerCase() == 'latitude' ||
                timeKey.toLowerCase() == 'longitude') {
              continue;
            }

            // Expect a child property "speed_kmph"
            final speedVal = timeNode.child('speed_kmph').value;
            if (speedVal != null) {
              final speed = double.tryParse(speedVal.toString()) ?? 0.0;
              // parse hour from "7:00" or "07:00"
              final hourPart = timeKey.split(':').first;
              final hour = int.tryParse(hourPart) ?? -1;
              if (hour >= 0) {
                hours[hour] = speed;
                daySpeedList.add(speed);
              }
            }
          }

          if (hours.isNotEmpty) {
            hourlyData[dt] = hours;
          }
          if (daySpeedList.isNotEmpty) {
            dailySpeeds[dt] = daySpeedList;
          }
        }
      }

      // Build options for the current selectedRange (default "Day")
      _buildDateOptionsForRange(selectedRange);

      // If nothing selected yet set the first option
      if (selectedDate.isEmpty && dateOptions.isNotEmpty) {
        selectedDate = dateOptions.first;
      }

      // Build chart for current selection
      await _buildChartForSelection();
    } catch (e, st) {
      debugPrint("Error loading data: $e\n$st");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  DateTime? _parseDateKey(String key) {
    // Expects dd-MM-yyyy
    try {
      final parts = key.split('-');
      if (parts.length != 3) return null;
      final d = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final y = int.parse(parts[2]);
      return DateTime(y, m, d);
    } catch (e) {
      return null;
    }
  }

  int _weekNumber(DateTime date) {
    // simple week number within year (not strictly ISO but OK for grouping)
    final jan1 = DateTime(date.year, 1, 1);
    final dayOfYear = date.difference(jan1).inDays + 1;
    return ((dayOfYear + jan1.weekday - 1) / 7).ceil();
  }

  void _buildDateOptionsForRange(String range) {
    final availableDates = hourlyData.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // newest first

    final List<String> options = [];

    if (range == "Day") {
      // Last 14 available dates (dd-MM-yyyy)
      for (var i = 0; i < min(14, availableDates.length); i++) {
        final d = availableDates[i];
        options.add(_formatDateKey(d));
      }
    } else if (range == "Week") {
      // Unique week-year pairs
      final Set<String> weeks = {};
      for (final d in availableDates) {
        final week = _weekNumber(d);
        final label = "Week $week, ${d.year}";
        weeks.add(label);
      }
      final list = weeks.toList();
      // try to sort by year desc then week desc
      list.sort((a, b) {
        final aParts = a.replaceAll('Week ', '').split(', ');
        final bParts = b.replaceAll('Week ', '').split(', ');
        final aWeek = int.tryParse(aParts[0]) ?? 0;
        final aYear = int.tryParse(aParts[1]) ?? 0;
        final bWeek = int.tryParse(bParts[0]) ?? 0;
        final bYear = int.tryParse(bParts[1]) ?? 0;
        if (aYear != bYear) return bYear.compareTo(aYear);
        return bWeek.compareTo(aWeek);
      });
      options.addAll(list);
    } else if (range == "Month") {
      final Set<String> months = {};
      for (final d in availableDates) {
        final label = "${monthNames[d.month]} ${d.year}";
        months.add(label);
      }
      final list = months.toList();
      // sort by year desc then month desc
      list.sort((a, b) {
        final aParts = a.split(' ');
        final bParts = b.split(' ');
        final aMonth = monthNames.indexOf(aParts[0]);
        final aYear = int.tryParse(aParts[1]) ?? 0;
        final bMonth = monthNames.indexOf(bParts[0]);
        final bYear = int.tryParse(bParts[1]) ?? 0;
        if (aYear != bYear) return bYear.compareTo(aYear);
        return bMonth.compareTo(aMonth);
      });
      options.addAll(list);
    } else if (range == "Year") {
      final Set<int> years = {};
      for (final d in availableDates) {
        years.add(d.year);
      }
      final list = years.toList()..sort((a, b) => b.compareTo(a)); // desc
      options.addAll(list.map((y) => y.toString()));
    }

    setState(() {
      dateOptions = options;
      // if current selectedDate is not in options, set to first (if exists)
      if (dateOptions.isNotEmpty && !dateOptions.contains(selectedDate)) {
        selectedDate = dateOptions.first;
      }
    });
  }

  String _formatDateKey(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return "$dd-$mm-$yyyy";
  }

  Future<void> _buildChartForSelection() async {
    setState(() {
      isLoading = true;
      chartData = [];
      avgSpeed = maxSpeed = minSpeed = 0.0;
    });

    // Use a local snapshot of parsed data: hourlyData & dailySpeeds
    if (selectedRange == "Day") {
      await _buildDayChart();
    } else if (selectedRange == "Week") {
      await _buildWeekChart();
    } else if (selectedRange == "Month") {
      await _buildMonthChart();
    } else if (selectedRange == "Year") {
      await _buildYearChart();
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _buildDayChart() async {
    // selectedDate expected dd-MM-yyyy
    final dt = _parseDateKey(selectedDate);
    if (dt == null) {
      chartData = [];
      return;
    }

    final hours = hourlyData[dt] ?? {};
    if (hours.isEmpty) {
      chartData = [];
      avgSpeed = maxSpeed = minSpeed = 0.0;
      return;
    }

    final List<int> sortedHours = hours.keys.toList()..sort();
    final List<FlSpot> spots = [];
    final List<double> speeds = [];

    for (final h in sortedHours) {
      final speed = hours[h] ?? 0.0;
      spots.add(FlSpot(h.toDouble(), speed)); // x is actual hour like 7.0
      speeds.add(speed);
    }

    _computeStatsFromList(speeds);

    setState(() {
      chartData = spots;
    });
  }

  Future<void> _buildWeekChart() async {
    // selectedDate like "Week X, YYYY"
    final parts = selectedDate
        .replaceAll('Week ', '')
        .split(',')
        .map((s) => s.trim())
        .toList();
    if (parts.length < 2) {
      chartData = [];
      return;
    }
    final weekNum = int.tryParse(parts[0]) ?? -1;
    final year = int.tryParse(parts[1]) ?? -1;
    if (weekNum < 0 || year < 0) {
      chartData = [];
      return;
    }

    // Build a week -> we will map Monday..Sunday (index 0..6)
    final List<FlSpot> spots = [];
    final List<double> speedsForStats = [];

    // For each day of week get average speed for that date
    for (int weekdayIndex = 1; weekdayIndex <= 7; weekdayIndex++) {
      // find a DateTime in dailySpeeds that matches this weekNum & year & weekday
      DateTime? matchingDate;
      for (final d in dailySpeeds.keys) {
        if (d.year == year &&
            _weekNumber(d) == weekNum &&
            d.weekday == weekdayIndex) {
          matchingDate = d;
          break;
        }
      }
      double avgForDay = 0.0;
      if (matchingDate != null) {
        final list = dailySpeeds[matchingDate]!;
        if (list.isNotEmpty) {
          avgForDay = list.reduce((a, b) => a + b) / list.length;
        }
      }
      spots.add(FlSpot((weekdayIndex - 1).toDouble(), avgForDay));
      speedsForStats.add(avgForDay);
    }

    _computeStatsFromList(speedsForStats);

    setState(() {
      chartData = spots;
    });
  }

  Future<void> _buildMonthChart() async {
    // selectedDate like "September 2025"
    final parts = selectedDate.split(' ');
    if (parts.length < 2) {
      chartData = [];
      return;
    }
    final monthName = parts[0];
    final year = int.tryParse(parts[1]) ?? -1;
    final month = monthNames.indexOf(monthName);
    if (month <= 0 || year < 0) {
      chartData = [];
      return;
    }

    final daysInMonth = DateTime(year, month + 1, 0).day;
    final List<FlSpot> spots = [];
    final List<double> statsList = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final d = DateTime(year, month, day);
      final speeds = dailySpeeds[d] ?? [];
      double avg = 0.0;
      if (speeds.isNotEmpty) {
        avg = speeds.reduce((a, b) => a + b) / speeds.length;
      }
      spots.add(FlSpot(day.toDouble(), avg));
      statsList.add(avg);
    }

    _computeStatsFromList(statsList);

    setState(() {
      chartData = spots;
    });
  }

  Future<void> _buildYearChart() async {
    // selectedDate like "2025"
    final year = int.tryParse(selectedDate) ?? -1;
    if (year < 0) {
      chartData = [];
      return;
    }

    final List<FlSpot> spots = [];
    final List<double> statsList = [];

    for (int month = 1; month <= 12; month++) {
      // gather all days in the month
      final monthlyDays = dailySpeeds.entries.where((entry) {
        final d = entry.key;
        return d.year == year && d.month == month;
      });

      double avgForMonth = 0.0;
      final List<double> allSpeeds = [];
      for (final entry in monthlyDays) {
        allSpeeds.addAll(entry.value);
      }
      if (allSpeeds.isNotEmpty) {
        avgForMonth = allSpeeds.reduce((a, b) => a + b) / allSpeeds.length;
      }
      spots.add(FlSpot(month.toDouble(), avgForMonth)); // x: 1..12
      statsList.add(avgForMonth);
    }

    _computeStatsFromList(statsList);

    setState(() {
      chartData = spots;
    });
  }

  void _computeStatsFromList(List<double> list) {
    if (list.isEmpty) {
      avgSpeed = maxSpeed = minSpeed = 0.0;
      return;
    }
    final filtered = list.where((v) => v > 0).toList();
    if (filtered.isEmpty) {
      avgSpeed = maxSpeed = minSpeed = 0.0;
      return;
    }
    final sum = filtered.reduce((a, b) => a + b);
    avgSpeed = sum / filtered.length;
    maxSpeed = filtered.reduce((a, b) => a > b ? a : b);
    minSpeed = filtered.reduce((a, b) => a < b ? a : b);
  }

  String getBottomTitle(double value) {
    switch (selectedRange) {
      case "Year":
        final idx = value.toInt();
        if (idx >= 1 && idx <= 12) return monthNames[idx].substring(0, 3);
        return '';
      case "Month":
        // day number
        return value.toInt().toString();
      case "Week":
        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final idx = value.toInt();
        return idx >= 0 && idx < days.length ? days[idx] : '';
      case "Day":
      default:
        return '${value.toInt()}:00';
    }
  }

  // When range button is tapped
  void _onRangeSelected(String range) {
    setState(() {
      selectedRange = range;
    });
    // rebuild date options for the selected range
    _buildDateOptionsForRange(range);
    // ensure selectedDate set to first available option
    if (dateOptions.isNotEmpty) {
      selectedDate = dateOptions.first;
    }
    _buildChartForSelection();
  }

  @override
  Widget build(BuildContext context) {
    // compute x range for chart (minX/maxX)
    double minX = 0;
    double maxX = 0;
    if (chartData.isNotEmpty) {
      minX = chartData.map((s) => s.x).reduce(min);
      maxX = chartData.map((s) => s.x).reduce(max);
    }

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
                ],
              ),
            ),

            // Main content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Speed History',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Range selector
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
                                  onTap: () => _onRangeSelected(e),
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

                    const SizedBox(height: 16),

                    // Date dropdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
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
                              value: dateOptions.isNotEmpty
                                  ? selectedDate
                                  : null,
                              hint: Text(
                                dateOptions.isEmpty ? "No dates" : "Select",
                                style: GoogleFonts.poppins(fontSize: 13),
                              ),
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
                                if (value == null) return;
                                setState(() {
                                  selectedDate = value;
                                });
                                _buildChartForSelection();
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

                    const SizedBox(height: 16),

                    // Chart Card
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
                          child: isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          "$selectedRange Speed Analysis",
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey[800],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),

                                    // Chart
                                    Expanded(
                                      child: LineChart(
                                        LineChartData(
                                          minX: chartData.isNotEmpty ? minX : 0,
                                          maxX: chartData.isNotEmpty ? maxX : 1,
                                          minY: 0,
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
                                            getDrawingVerticalLine: (value) =>
                                                FlLine(
                                                  color: Colors.grey[200]!,
                                                  strokeWidth: 1,
                                                ),
                                          ),
                                          titlesData: FlTitlesData(
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 44,
                                                interval: 10,
                                                getTitlesWidget:
                                                    (value, meta) => Text(
                                                      '${value.toInt()}',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 11,
                                                            color: Colors
                                                                .grey[600],
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                    ),
                                              ),
                                            ),
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 36,
                                                interval: 1,
                                                getTitlesWidget:
                                                    (value, meta) => Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            top: 8,
                                                          ),
                                                      child: Text(
                                                        getBottomTitle(value),
                                                        style:
                                                            GoogleFonts.poppins(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .grey[600],
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w400,
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
                                              color: Colors.blue,
                                              barWidth: 3,
                                              dotData: FlDotData(
                                                show: true,
                                                getDotPainter:
                                                    (
                                                      spot,
                                                      percent,
                                                      bar,
                                                      index,
                                                    ) => FlDotCirclePainter(
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
                                                    Colors.blue.withOpacity(
                                                      0.15,
                                                    ),
                                                    Colors.blue.withOpacity(
                                                      0.0,
                                                    ),
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
                                                    '${spot.y.toStringAsFixed(1)} km/h',
                                                    GoogleFonts.poppins(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w500,
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

                                    const SizedBox(height: 24),

                                    // Stats row
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
                                            "${avgSpeed.toStringAsFixed(1)} km/h",
                                            Icons.timeline,
                                          ),
                                          _buildStat(
                                            "Maximum",
                                            "${maxSpeed.toStringAsFixed(1)} km/h",
                                            Icons.keyboard_arrow_up,
                                          ),
                                          _buildStat(
                                            "Minimum",
                                            "${minSpeed.toStringAsFixed(1)} km/h",
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

