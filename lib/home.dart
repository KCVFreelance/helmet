import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'signin.dart'; // Import to access UserSession

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
  
  static const String GOOGLE_MAPS_API_KEY = 'AIzaSyAetVajoczNEi6uSLwwD_vpeHEDIdNgcQs';

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
                _calculateDistance(_lastSpeedLimitLatitude!, _lastSpeedLimitLongitude!, lat, lng) > 100) {
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
          _currentDuration = DateTime.now().difference(_startTime!);
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

  String _getTimePeriod(DateTime dateTime) {
    int hour = dateTime.hour;
    if (hour >= 16 && hour <= 23) {
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
        
        if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
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

    final travelTimeSeconds = _stopTime!.difference(_startTime!).inSeconds;

    final travelDistance = _calculateDistance(
      _startLatitude!,
      _startLongitude!,
      _stopLatitude!,
      _stopLongitude!,
    ) / 1000;

    final timePeriod = _getTimePeriod(_startTime!);

    final dateStr =
        "${_startTime!.month.toString().padLeft(2, '0')}-${_startTime!.day.toString().padLeft(2, '0')}-${_startTime!.year}";

    try {
      await _database.child('$helmetId/recentTrips/$timePeriod').set({
        'date': "$dateStr",
        'distance': travelDistance.toStringAsFixed(2),
        'tTime': travelTimeSeconds,
      });
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

  Widget _buildSpeedLimitCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "SPEED LIMIT",
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A1D29),
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFEF4444),
                    width: 6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
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
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEF4444),
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          height: 1.0,
                        ),
                      ),
                      Text(
                        'km/h',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFEF4444),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          height: 1.0,
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
    );
  }

  Widget _buildSpeedDisplayCard() {
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "CURRENT",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7280),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            _currentSpeed.toStringAsFixed(1),
            style: GoogleFonts.inter(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: speedColor,
              letterSpacing: -1.0,
            ),
          ),
          
          Text(
            "km/h",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelTimeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            "TRAVEL TIME",
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF6B7280),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          
          Text(
            _travelTimeDisplay.split(':').sublist(1).join(':'), // Remove hours for cleaner display
            style: GoogleFonts.inter(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1D29),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.blue[700],
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
                    "Top Shield",
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

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome back,",
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _userName,
                            style: GoogleFonts.inter(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A1D29),
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Speed Limit and Current Speed in same row
                    Row(
                      children: [
                        Expanded(
                          child: _buildSpeedLimitCard(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSpeedDisplayCard(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Travel Time below
                    _buildTravelTimeCard(),
                    const SizedBox(height: 24),

                    // System Status Card (Journey Control without title)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueGrey.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withOpacity(0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.directions_bike_outlined,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final helmetId = _helmetId;
                                    if (helmetId == null) return;

                                    final coordSnapshot = await _database
                                        .child('$helmetId/coordinates/gps')
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
                                      await _database
                                          .child('$helmetId/start')
                                          .set({
                                            'date': dateStr,
                                            'time': timeStr,
                                            'latitude': lat,
                                            'longitude': lng,
                                          });
                                    } else {
                                      await _database
                                          .child('$helmetId/stop')
                                          .set({
                                            'date': dateStr,
                                            'time': timeStr,
                                            'latitude': lat,
                                            'longitude': lng,
                                          });

                                      await _saveTripData();
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isStarted
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF3B82F6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 0,
                                    shadowColor: (_isStarted 
                                        ? const Color(0xFFEF4444) 
                                        : const Color(0xFF3B82F6)).withOpacity(0.3),
                                  ),
                                  child: Text(
                                    _isStarted ? 'Stop Journey' : 'Start Journey',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildFeatureCard(
                      icon: Icons.timeline_outlined,
                      iconColor: const Color(0xFF3B82F6),
                      title: "Speed History",
                      description:
                          "View your speed records and detailed analytics to track your driving patterns.",
                      buttonText: "View Analytics",
                      buttonColor: const Color(0xFF3B82F6),
                      cardColor: const Color(0xFFEFF6FF),
                      onPressed: () {
                        if (widget.onNavigateToHistory != null) {
                          widget
                              .onNavigateToHistory!();
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    Row(
                      children: [
                        Expanded(
                          child: _buildFeatureCard(
                            icon: Icons.local_parking_outlined,
                            iconColor: const Color(0xFF10B981),
                            title: "Parking Location",
                            description:
                                "Find where you parked your vehicle with precise location tracking.",
                            buttonText: "Find Location",
                            buttonColor: const Color(0xFF10B981),
                            cardColor: const Color(0xFFECFDF5),
                            isCompact: true,
                            onPressed: () {
                              if (widget.onNavigateToMap != null) {
                                widget.onNavigateToMap!();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildFeatureCard(
                            icon: Icons.bar_chart_outlined,
                            iconColor: const Color(0xFF8B5CF6),
                            title: "Travel Statistics",
                            description:
                                "Comprehensive travel data and performance metrics analysis.",
                            buttonText: "View Stats",
                            buttonColor: const Color(0xFF8B5CF6),
                            cardColor: const Color(0xFFF5F3FF),
                            isCompact: true,
                            onPressed: () {
                              if (widget.onNavigateToProfile != null) {
                                widget.onNavigateToProfile!();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
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
    required Color iconColor,
    required String title,
    required String description,
    required String buttonText,
    required Color buttonColor,
    required Color cardColor,
    bool isCompact = false,
    required VoidCallback onPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: iconColor.withOpacity(0.2),
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1D29),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: isCompact ? 12 : 16),

          Text(
            description,
            style: GoogleFonts.inter(
              fontSize: isCompact ? 13 : 14,
              color: const Color(0xFF6B7280),
              height: 1.4,
              fontWeight: FontWeight.w400,
            ),
          ),

          SizedBox(height: isCompact ? 16 : 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: isCompact ? 12 : 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                buttonText,
                style: GoogleFonts.inter(
                  fontSize: isCompact ? 14 : 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
