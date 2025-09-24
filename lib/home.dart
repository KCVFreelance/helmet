import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'signin.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToHistory;
  final VoidCallback? onNavigateToMap;
  final VoidCallback? onNavigateToProfile;

  const HomePage({
    super.key,
    this.onNavigateToHistory,
    this.onNavigateToMap,
    this.onNavigateToProfile,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isStarted = false;
  String _userName = "";

  double latitude = 14.5995;
  double longitude = 120.9842;

  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  DateTime? _startTime;
  DateTime? _stopTime;
  Timer? _timer;
  Duration _currentDuration = Duration.zero;

  double? _startLatitude;
  double? _startLongitude;
  double? _stopLatitude;
  double? _stopLongitude;

  double _currentSpeed = 0.0;
  StreamSubscription<DatabaseEvent>? _coordSubscription;

  bool _isLoadingSpeedLimit = false;
  String? _speedLimitError;
  int? _speedLimit;
  String? _roadName;
  String? _currentAddress;
  double? _lastSpeedLimitLatitude;
  double? _lastSpeedLimitLongitude;

  static const String GOOGLE_MAPS_API_KEY =
      'AIzaSyAetVajoczNEi6uSLwwD_vpeHEDIdNgcQs';

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
        .child('$helmetId/coordinates/gps')
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

            final rawLat = coordData['latitude'];
            final rawLng = coordData['longitude'];
            double lat = 0.0;
            double lng = 0.0;

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

            setState(() {
              _currentSpeed = speed;
              latitude = lat;
              longitude = lng;
            });

            if (_lastSpeedLimitLatitude == null ||
                _lastSpeedLimitLongitude == null ||
                _calculateDistance(
                      _lastSpeedLimitLatitude!,
                      _lastSpeedLimitLongitude!,
                      lat,
                      lng,
                    ) >
                    100) {
              _getSpeedLimitForLocation(lat, lng);
            }
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
          // Use Philippine time for duration calculation
          _currentDuration = _nowPhilippines.difference(_startTime!);
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String? get _helmetId => UserSession.helmetId;

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;

    double dLat = _degreesToRadians(lat2 - lat1);
    double dLon = _degreesToRadians(lon2 - lon1);

    double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c * 1000;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  // Updated time period logic - based on stop time
  String _getTimePeriod(DateTime dateTime) {
    int hour = dateTime.hour;
    // Evening: 16:00 to 1:59 (next day)
    // Morning: 2:00 to 15:59
    if (hour >= 16 || hour <= 1) {
      return 'evening';
    } else {
      return 'morning';
    }
  }

  Future<void> _getSpeedLimitForLocation(double lat, double lng) async {
    if (_isLoadingSpeedLimit) return;

    _lastSpeedLimitLatitude = lat;
    _lastSpeedLimitLongitude = lng;

    setState(() {
      _isLoadingSpeedLimit = true;
      _speedLimitError = null;
    });

    try {
      await _getRoadInfo(lat, lng);
      await _getSpeedLimitFromRoadsAPI(lat, lng);
    } catch (e) {
      debugPrint('Error getting speed limit: $e');
      setState(() {
        _speedLimitError = 'Unable to fetch speed limit data';
      });
    } finally {
      setState(() {
        _isLoadingSpeedLimit = false;
      });
    }
  }

  Future<void> _getRoadInfo(double lat, double lng) async {
    try {
      final uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'latlng': '$lat,$lng',
        'key': GOOGLE_MAPS_API_KEY,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' &&
            data['results'] != null &&
            data['results'].isNotEmpty) {
          final result = data['results'][0];

          String? roadName;
          String? formattedAddress = result['formatted_address'];

          for (var component in result['address_components']) {
            final types = List<String>.from(component['types']);
            if (types.contains('route')) {
              roadName = component['long_name'];
              break;
            }
          }

          setState(() {
            _roadName = roadName;
            _currentAddress = formattedAddress;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting road info: $e');
    }
  }

  Future<void> _getSpeedLimitFromRoadsAPI(double lat, double lng) async {
    try {
      final uri = Uri.https('roads.googleapis.com', '/v1/speedLimits', {
        'path': '$lat,$lng',
        'key': GOOGLE_MAPS_API_KEY,
      });

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['speedLimits'] != null && data['speedLimits'].isNotEmpty) {
          final speedLimitData = data['speedLimits'][0];
          final speedLimitKph = speedLimitData['speedLimit'];

          setState(() {
            _speedLimit = speedLimitKph.round();
          });
          final helmetId = _helmetId;
          if (helmetId != null) {
            await _database.child('$helmetId/speedlimit').set(_speedLimit);
          }
        } else {
          _setDefaultSpeedLimit();
        }
      } else {
        _setDefaultSpeedLimit();
      }
    } catch (e) {
      debugPrint('Error getting speed limit from Roads API: $e');
      _setDefaultSpeedLimit();
    }
  }

  void _setDefaultSpeedLimit() {
    int defaultSpeed = 60;

    if (_roadName != null) {
      final roadNameLower = _roadName!.toLowerCase();

      if (roadNameLower.contains('highway') ||
          roadNameLower.contains('expressway') ||
          roadNameLower.contains('freeway')) {
        defaultSpeed = 100;
      } else if (roadNameLower.contains('avenue') ||
          roadNameLower.contains('boulevard')) {
        defaultSpeed = 60;
      } else if (roadNameLower.contains('street') ||
          roadNameLower.contains('road')) {
        defaultSpeed = 40;
      }
    }

    setState(() {
      _speedLimit = defaultSpeed;
    });

    final helmetId = _helmetId;
    if (helmetId != null) {
      _database.child('$helmetId/speedlimit').set(defaultSpeed);
    }
  }

  // Helper to get Philippine time (UTC+8)
  DateTime get _nowPhilippines =>
      DateTime.now().toUtc().add(const Duration(hours: 8));

  // Updated save trip data function
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

    // Calculate travel time in seconds
    final travelTimeSeconds = _stopTime!.difference(_startTime!).inSeconds;

    // Calculate travel distance in kilometers
    final travelDistance =
        _calculateDistance(
          _startLatitude!,
          _startLongitude!,
          _stopLatitude!,
          _stopLongitude!,
        ) /
        1000;

    // Get time period based on stop time
    final timePeriod = _getTimePeriod(_stopTime!);

    // Use the stop time as stored in the database for the key
    final stopSnap = await _database.child('$helmetId/stop').get();
    String stopTimeKey = '';
    String dateStr = '';
    if (stopSnap.exists && stopSnap.value is Map) {
      final data = stopSnap.value as Map;
      if (data['date'] != null && data['time'] != null) {
        dateStr = data['date'];
        final timeParts = (data['time'] as String).split(':');
        if (timeParts.length >= 2) {
          stopTimeKey =
              "${timeParts[0].padLeft(2, '0')}:${timeParts[1].padLeft(2, '0')}";
        }
      }
    }
    if (dateStr.isEmpty) {
      // fallback to computed date if not found
      final stopPH = _stopTime!.toUtc().add(const Duration(hours: 8));
      dateStr =
          "${stopPH.month.toString().padLeft(2, '0')}-${stopPH.day.toString().padLeft(2, '0')}-${stopPH.year}";
    }
    if (stopTimeKey.isEmpty) {
      // fallback to computed time if not found
      final stopPH = _stopTime!.toUtc().add(const Duration(hours: 8));
      stopTimeKey =
          "${stopPH.hour.toString().padLeft(2, '0')}:${stopPH.minute.toString().padLeft(2, '0')}";
    }

    try {
      // Save to recentTrips with time period based on stop time
      await _database.child('$helmetId/recentTrips/$timePeriod').set({
        'date': dateStr,
        'distance': travelDistance.toStringAsFixed(2),
        'tTime': travelTimeSeconds,
      });

      // Save to coordinates with time based on stop time (hour:minute only)
      await _database
          .child('$helmetId/coordinates/$dateStr/$stopTimeKey/tDistance')
          .set(travelDistance.toStringAsFixed(2));

      debugPrint('Trip data saved successfully:');
      debugPrint('Date: $dateStr');
      debugPrint('Time Period: $timePeriod');
      debugPrint('Distance: ${travelDistance.toStringAsFixed(2)} km');
      debugPrint('Travel Time: $travelTimeSeconds seconds');
    } catch (e) {
      debugPrint('Error saving trip data: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTripState();
    _listenToCurrentSpeed();
    _loadUserName();
  }

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
          // Parse as Philippine time
          startTime = DateTime.tryParse(
            '${data['date']}T${data['time']}+08:00',
          );
        }
      }
      if (stopSnap.exists && stopSnap.value is Map) {
        final data = stopSnap.value as Map;
        if (data['date'] != null && data['time'] != null) {
          // Parse as Philippine time
          stopTime = DateTime.tryParse('${data['date']}T${data['time']}+08:00');
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
            ? _nowPhilippines.difference(_startTime!)
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

  Widget _buildDashboardCard() {
    Color speedColor = const Color(0xFF3B82F6);
    if (_speedLimit != null && _currentSpeed > _speedLimit!) {
      speedColor = const Color(0xFFEF4444);
    } else if (_currentSpeed > 0) {
      speedColor = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Speed Metrics Row
          Row(
            children: [
              // Speed Limit
              Expanded(
                child: Column(
                  children: [
                    Text(
                      "SPEED LIMIT",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFEF4444),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEF4444).withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _isLoadingSpeedLimit
                                  ? '...'
                                  : (_speedLimit?.toString() ?? '--'),
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFEF4444),
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              'km/h',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFEF4444),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Current Speed
              Expanded(
                child: Column(
                  children: [
                    Text(
                      "CURRENT SPEED",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _currentSpeed.toInt().toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: speedColor,
                        letterSpacing: -1.0,
                      ),
                    ),
                    Text(
                      "km/h",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Divider
          Container(height: 1, color: const Color(0xFFF3F4F6)),
          const SizedBox(height: 24),

          // Travel Time and Control
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TRAVEL TIME",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _travelTimeDisplay,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1F2937),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Start/Stop Button
              SizedBox(
                width: 140,
                child: ElevatedButton(
                  onPressed: _handleTripControl,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStarted
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                  ),
                  child: Text(
                    _isStarted ? 'STOP' : 'START',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Updated trip control function with new date format
  Future<void> _handleTripControl() async {
    final helmetId = _helmetId;
    if (helmetId == null) return;

    final coordSnapshot = await _database
        .child('$helmetId/coordinates/gps')
        .get();
    double lat = 0.0;
    double lng = 0.0;

    if (coordSnapshot.exists) {
      final coordData = coordSnapshot.value as Map<dynamic, dynamic>;
      final rawLat = coordData['latitude'];
      final rawLng = coordData['longitude'];

      if (rawLat is double)
        lat = rawLat;
      else if (rawLat is int)
        lat = rawLat.toDouble();
      else if (rawLat is String)
        lat = double.tryParse(rawLat) ?? 0.0;

      if (rawLng is double)
        lng = rawLng;
      else if (rawLng is int)
        lng = rawLng.toDouble();
      else if (rawLng is String)
        lng = double.tryParse(rawLng) ?? 0.0;
    }

    // Use Philippine time
    final now = _nowPhilippines;
    setState(() {
      _isStarted = !_isStarted;
      if (_isStarted) {
        _startTime = now;
        _stopTime = null;
        _currentDuration = Duration.zero;
        _startLatitude = lat;
        _startLongitude = lng;
        _startTimer();
      } else {
        _stopTime = now;
        _stopLatitude = lat;
        _stopLongitude = lng;
        _stopTimer();
        if (_startTime != null && _stopTime != null) {
          _currentDuration = _stopTime!.difference(_startTime!);
        }
      }
    });

    // Updated date format to MM-DD-YYYY, using Philippine time
    final dateStr =
        "${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}-${now.year}";
    final timeStr =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    if (_isStarted) {
      await _database.child('$helmetId/start').set({
        'date': dateStr,
        'time': timeStr,
        'latitude': lat,
        'longitude': lng,
      });
    } else {
      await _database.child('$helmetId/stop').set({
        'date': dateStr,
        'time': timeStr,
        'latitude': lat,
        'longitude': lng,
      });
      // Save trip data when stopping
      await _saveTripData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Simplified Header (Live banner removed)
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[700],
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  Text(
                    "Top Shield",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome back,",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userName.isNotEmpty ? _userName : "Driver",
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1F2937),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Dashboard Card
                    _buildDashboardCard(),
                    const SizedBox(height: 24),

                    // Speed Analytics Card (Full width)
                    _buildFeatureCard(
                      icon: Icons.analytics_outlined,
                      title: "Speed Analytics",
                      description:
                          "View detailed speed history and driving patterns",
                      iconColor: const Color(0xFF3B82F6),
                      cardColor: const Color(0xFFEFF6FF),
                      buttonColor: const Color(0xFF3B82F6),
                      onPressed: widget.onNavigateToHistory,
                      isFullWidth: true,
                    ),
                    const SizedBox(height: 16),

                    // Parking Locator and Travel Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildFeatureCard(
                            icon: Icons.location_on_outlined,
                            title: "Parking Locator",
                            description: "Find your parked vehicle location",
                            iconColor: const Color(0xFF10B981),
                            cardColor: const Color(0xFFECFDF5),
                            buttonColor: const Color(0xFF10B981),
                            onPressed: widget.onNavigateToMap,
                            isFullWidth: false,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFeatureCard(
                            icon: Icons.bar_chart_outlined,
                            title: "Travel Stats",
                            description: "Comprehensive travel metrics",
                            iconColor: const Color(0xFF8B5CF6),
                            cardColor: const Color(0xFFF5F3FF),
                            buttonColor: const Color(0xFF8B5CF6),
                            onPressed: widget.onNavigateToProfile,
                            isFullWidth: false,
                          ),
                        ),
                      ],
                    ),

                    // Add some bottom padding to ensure all content is visible
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color iconColor,
    required Color cardColor,
    required Color buttonColor,
    required VoidCallback? onPressed,
    required bool isFullWidth,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.all(20),
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Centered Icon at the top
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor.withOpacity(0.2)),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),

                const SizedBox(height: 12),

                // Title below the icon
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: isFullWidth ? 18 : 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1F2937),
                    letterSpacing: -0.3,
                  ),
                ),

                const SizedBox(height: 8),

                // Description below the title
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: isFullWidth ? 14 : 13,
                    color: const Color(0xFF6B7280),
                    height: 1.4,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 16),

                // Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: buttonColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      "View",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
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
