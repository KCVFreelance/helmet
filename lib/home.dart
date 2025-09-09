import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'signin.dart'; // Import to access UserSession

// Change HomePage to StatefulWidget to manage button state
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isStarted = false;
  String _userName = ""; // Add this line for user's name

  double latitude = 14.5995; // Replace with actual latitude
  double longitude = 120.9842; // Replace with actual longitude

  // Add Firebase Database reference
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  DateTime? _startTime;
  DateTime? _stopTime;
  Timer? _timer;
  Duration _currentDuration = Duration.zero;

  // Add variables to store start and stop coordinates
  double? _startLatitude;
  double? _startLongitude;
  double? _stopLatitude;
  double? _stopLongitude;

  double _currentSpeed = 0.0;
  StreamSubscription<DatabaseEvent>? _coordSubscription;

  // Removed duplicate initState

  @override
  void dispose() {
    _coordSubscription?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _listenToCurrentSpeed() {
    final helmetId = _helmetId;
    if (helmetId == null) return;
    _coordSubscription = _database
        .child('$helmetId/coordinates')
        .onValue
        .listen((event) {
          if (event.snapshot.exists) {
            final coordData = event.snapshot.value as Map<dynamic, dynamic>;
            final cSpeed = coordData['cSpeed'];
            double speed = 0.0;
            if (cSpeed is double)
              speed = cSpeed;
            else if (cSpeed is int)
              speed = cSpeed.toDouble();
            else if (cSpeed is String)
              speed = double.tryParse(cSpeed) ?? 0.0;
            setState(() {
              _currentSpeed = speed;
            });
          }
        });
  }

  String get _travelTimeDisplay {
    if (_isStarted && _startTime != null) {
      return _formatDuration(_currentDuration);
    }
    if (_startTime != null && _stopTime != null) {
      final duration = _stopTime!.difference(_startTime!);
      return _formatDuration(duration);
    }
    return "00:00:00";
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = twoDigits(d.inHours);
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return "$h:$m:$s";
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_startTime != null) {
        setState(() {
          _currentDuration = DateTime.now().difference(_startTime!);
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String? get _helmetId => UserSession.helmetId;

  // Function to calculate distance between two coordinates using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c; // Distance in kilometers
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Function to determine time period (Morning or Evening)
  String _getTimePeriod(DateTime dateTime) {
    int hour = dateTime.hour;
    if (hour >= 16 && hour <= 23) {
      return 'evening';
    } else {
      return 'morning';
    }
  }

  // Function to save trip data to recentTrips
  Future<void> _saveTripData() async {
    final helmetId = _helmetId;
    if (helmetId == null ||
        _startTime == null ||
        _stopTime == null ||
        _startLatitude == null ||
        _startLongitude == null ||
        _stopLatitude == null ||
        _stopLongitude == null) {
      return;
    }

    // Calculate travel time in minutes (stop time minus start time)
    final travelTimeMinutes = _stopTime!.difference(_startTime!).inMinutes;

    // Calculate travel distance in kilometers
    final travelDistance = _calculateDistance(
      _startLatitude!,
      _startLongitude!,
      _stopLatitude!,
      _stopLongitude!,
    );

    // Determine time period based on start time
    final timePeriod = _getTimePeriod(_startTime!);

    // Format date as MM-DD-YYYY
    final dateStr =
        "${_startTime!.month.toString().padLeft(2, '0')}-${_startTime!.day.toString().padLeft(2, '0')}-${_startTime!.year}";

    // Save to recentTrips
    try {
      await _database.child('$helmetId/recentTrips/$timePeriod').set({
        'date': dateStr, // MM-DD-YYYY format
        'distance': travelDistance.toStringAsFixed(
          2,
        ), // Distance in km with 2 decimal places
        'tTime':
            travelTimeMinutes, // Travel time in minutes (stop time - start time)
      });
      // Also save distance to coordinates/{date}/{time}/tDistance
      final timeKey =
          "${_stopTime!.hour.toString().padLeft(2, '0')}:${_stopTime!.minute.toString().padLeft(2, '0')}";
      await _database
          .child('$helmetId/coordinates/$dateStr/$timeKey/tDistance')
          .set(travelDistance.toStringAsFixed(2));
    } catch (e) {
      print('Error saving trip data: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTripState();
    _listenToCurrentSpeed();
    _loadUserName(); // Add this line
  }

  // Add this function to load user name
  Future<void> _loadUserName() async {
    final helmetId = _helmetId;
    if (helmetId == null) return;
    try {
      final snapshot = await _database.child('$helmetId/accounts').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _userName = data['fname'] ?? "";
        });
      }
    } catch (_) {}
  }

  Future<void> _loadTripState() async {
    final helmetId = _helmetId;
    if (helmetId == null) return;
    try {
      final startSnap = await _database.child('$helmetId/start').get();
      final stopSnap = await _database.child('$helmetId/stop').get();
      DateTime? startTime;
      DateTime? stopTime;
      if (startSnap.exists && startSnap.value is Map) {
        final data = startSnap.value as Map;
        if (data['date'] != null && data['time'] != null) {
          startTime = DateTime.tryParse('${data['date']}T${data['time']}');
        }
      }
      if (stopSnap.exists && stopSnap.value is Map) {
        final data = stopSnap.value as Map;
        if (data['date'] != null && data['time'] != null) {
          stopTime = DateTime.tryParse('${data['date']}T${data['time']}');
        }
      }
      bool started = false;
      if (startTime != null &&
          (stopTime == null || startTime.isAfter(stopTime))) {
        started = true;
      }
      setState(() {
        _isStarted = started;
        _startTime = started ? startTime : null;
        _stopTime = started ? null : stopTime;
        _currentDuration = started && _startTime != null
            ? DateTime.now().difference(_startTime!)
            : Duration.zero;
      });
      if (started) _startTimer();
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadTripState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Topshield",
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

              // Main content area
              SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome back, $_userName!",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            "Dashboard",
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Online",
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // System Status Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "System Status",
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    "Active",
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[700],
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green[400]!,
                                    Colors.green[600]!,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stats Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.speed_outlined,
                                iconColor: Colors.blue,
                                label: "Current Speed",
                                value:
                                    "${_currentSpeed.toStringAsFixed(1)} km/h",
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.access_time_outlined,
                                iconColor: Colors.orange,
                                label: "Travel Time",
                                value: _travelTimeDisplay,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Start/Stop button: full width and centered
                        Row(
                          children: [
                            Expanded(
                              child: Center(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final helmetId = _helmetId;
                                      if (helmetId == null) return;

                                      // Fetch coordinates from RTDB
                                      final coordSnapshot = await _database
                                          .child('$helmetId/coordinates')
                                          .get();
                                      double lat = 0.0;
                                      double lng = 0.0;
                                      if (coordSnapshot.exists) {
                                        final coordData =
                                            coordSnapshot.value
                                                as Map<dynamic, dynamic>;
                                        final rawLat = coordData['latitude'];
                                        final rawLng = coordData['longitude'];
                                        if (rawLat is double) {
                                          lat = rawLat;
                                        } else if (rawLat is int) {
                                          lat = rawLat.toDouble();
                                        } else if (rawLat is String) {
                                          lat = double.tryParse(rawLat) ?? 0.0;
                                        }
                                        if (rawLng is double) {
                                          lng = rawLng;
                                        } else if (rawLng is int) {
                                          lng = rawLng.toDouble();
                                        } else if (rawLng is String) {
                                          lng = double.tryParse(rawLng) ?? 0.0;
                                        }
                                      }

                                      setState(() {
                                        _isStarted = !_isStarted;
                                        if (_isStarted) {
                                          _startTime = DateTime.now();
                                          _stopTime = null;
                                          _currentDuration = Duration.zero;
                                          _startLatitude = lat;
                                          _startLongitude = lng;
                                          _startTimer();
                                        } else {
                                          _stopTime = DateTime.now();
                                          _stopLatitude = lat;
                                          _stopLongitude = lng;
                                          _stopTimer();
                                          if (_startTime != null &&
                                              _stopTime != null) {
                                            _currentDuration = _stopTime!
                                                .difference(_startTime!);
                                          }
                                        }
                                      });

                                      final now = DateTime.now();
                                      final dateStr =
                                          "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
                                      final timeStr =
                                          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

                                      if (_isStarted) {
                                        // Start pressed
                                        await _database
                                            .child('$helmetId/start')
                                            .set({
                                              'date': dateStr,
                                              'time': timeStr,
                                              'latitude': lat,
                                              'longitude': lng,
                                            });
                                      } else {
                                        // Stop pressed
                                        await _database
                                            .child('$helmetId/stop')
                                            .set({
                                              'date': dateStr,
                                              'time': timeStr,
                                              'latitude': lat,
                                              'longitude': lng,
                                            });

                                        // Calculate and save trip data
                                        await _saveTripData();
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _isStarted
                                          ? Colors.red
                                          : Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      _isStarted ? 'Stop' : 'Start',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Speed History Card
                  _buildFeatureCard(
                    icon: Icons.timeline_outlined,
                    iconColor: Colors.blue,
                    title: "Speed History",
                    description:
                        "View your speed records and detailed analytics to track your driving patterns.",
                    buttonText: "View Analytics",
                    buttonColor: Colors.blue,
                    gradient: [Colors.blue[50]!, Colors.blue[100]!],
                  ),
                  const SizedBox(height: 20),

                  // Bottom Row - Two Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.local_parking_outlined,
                          iconColor: Colors.green,
                          title: "Parking Location",
                          description:
                              "Find where you parked your vehicle with precise location tracking.",
                          buttonText: "Find Location",
                          buttonColor: Colors.green,
                          gradient: [Colors.green[50]!, Colors.green[100]!],
                          isCompact: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildFeatureCard(
                          icon: Icons.bar_chart_outlined,
                          iconColor: Colors.purple,
                          title: "Travel Statistics",
                          description:
                              "Comprehensive travel data and performance metrics analysis.",
                          buttonText: "View Stats",
                          buttonColor: Colors.purple,
                          gradient: [Colors.purple[50]!, Colors.purple[100]!],
                          isCompact: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String buttonText,
    required Color buttonColor,
    required List<Color> gradient,
    bool isCompact = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: isCompact ? 12 : 16),

          // Description
          Text(
            description,
            style: GoogleFonts.poppins(
              fontSize: isCompact ? 12 : 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            maxLines: isCompact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
          ),

          SizedBox(height: isCompact ? 16 : 20),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                shadowColor: buttonColor.withOpacity(0.3),
              ),
              child: Text(
                buttonText,
                style: GoogleFonts.poppins(
                  fontSize: isCompact ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
