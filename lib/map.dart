// pubspec.yaml dependencies needed:
// flutter_map: ^6.0.1
// latlong2: ^0.8.1
// http: ^1.1.0
// geolocator: ^10.1.0

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Firebase Reference
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  
  // Locations
  LatLng? startLocation;
  LatLng? endLocation;
  List<LatLng> routePoints = [];
  
  // Map state
  bool isRouteVisible = false;
  bool isLoading = false;
  String? eta;
  String? distance;
  double currentZoom = 15.0;
  bool showRouteInfo = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initLocation();
    _setupStopLocationListener();
    _fetchEndLocation();
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    if (startLocation == null || endLocation == null) return;
    
    setState(() {
      isLoading = true;
    });

    try {
      final apiUrl = 'https://router.project-osrm.org/route/v1/foot/'
        '${startLocation!.longitude},${startLocation!.latitude};'
        '${endLocation!.longitude},${endLocation!.latitude}'
        '?overview=full&geometries=geojson';
      print(apiUrl);
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final coordinates = data['routes'][0]['geometry']['coordinates'];
        final duration = data['routes'][0]['duration'];
        final dist = data['routes'][0]['distance'];
        
        setState(() {
          routePoints = coordinates.map<LatLng>((coord) => 
            LatLng(coord[1].toDouble(), coord[0].toDouble())).toList();
          isRouteVisible = true;
          eta = _formatDuration(duration);
          distance = _formatDistance(dist);
          showRouteInfo = true;
        });
        
        _fitRouteBounds();
      }
    } catch (e) {
      print('Error loading route: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _fitRouteBounds() {
    if (routePoints.isNotEmpty && startLocation != null && endLocation != null) {
      final bounds = LatLngBounds.fromPoints([startLocation!, endLocation!, ...routePoints]);
      _mapController.fitCamera(CameraFit.bounds(
        bounds: bounds, 
        padding: EdgeInsets.only(
          top: 120,
          bottom: showRouteInfo ? 200 : 100,
          left: 60,
          right: 60,
        )
      ));
    }
  }

  Future<void> _initLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        startLocation = LatLng(position.latitude, position.longitude);
      });

      await _fetchEndLocation();
      if (startLocation != null && endLocation != null) {
        await _loadRoute();
      }
      
      Geolocator.getPositionStream().listen((Position position) {
        if (mounted) {
          setState(() {
            startLocation = LatLng(position.latitude, position.longitude);
          });
          _loadRoute();
        }
      });

    } catch (e) {
      print('Error getting location: $e');
    }
  }

  Future<void> _fetchEndLocation() async {
    try {
      final stopSnapshot = await _database.child('1-000/stop').get();
      if (stopSnapshot.exists) {
        final stopData = stopSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          endLocation = LatLng(
            (stopData['latitude'] ?? 0).toDouble(),
            (stopData['longitude'] ?? 0).toDouble(),
          );
        });
        if (startLocation != null && endLocation != null) {
          _loadRoute();
        }
      }
    } catch (e) {
      print('Error fetching end location: $e');
    }
  }

  void _setupStopLocationListener() {
    _database.child('1-000/stop').onValue.listen((event) {
      if (event.snapshot.exists) {
        final stopData = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          endLocation = LatLng(
            (stopData['latitude'] ?? 0).toDouble(),
            (stopData['longitude'] ?? 0).toDouble(),
          );
        });
        if (startLocation != null && endLocation != null) {
          _loadRoute();
        }
      }
    });
  }

  String _formatDuration(double seconds) {
    final duration = Duration(seconds: seconds.round());
    final hours = duration.inHours;
    final minutes = (duration.inMinutes % 60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      final km = (meters / 1000).toStringAsFixed(1);
      return '$km km';
    } else {
      return '${meters.round()} m';
    }
  }

  void _zoomIn() {
    currentZoom = (currentZoom + 1).clamp(1, 18);
    _mapController.move(_mapController.camera.center, currentZoom);
  }

  void _zoomOut() {
    currentZoom = (currentZoom - 1).clamp(1, 18);
    _mapController.move(_mapController.camera.center, currentZoom);
  }

  void _centerOnRoute() {
    HapticFeedback.lightImpact();
    _fitRouteBounds();
  }

  void _centerOnUserLocation() {
    HapticFeedback.lightImpact();
    if (startLocation != null) {
      _mapController.move(startLocation!, 16.0);
    }
  }

  void _recalculateRoute() {
    HapticFeedback.mediumImpact();
    _loadRoute();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: startLocation ?? LatLng(14.24754, 121.06361),
              initialZoom: currentZoom,
              minZoom: 4,
              maxZoom: 18,
              keepAlive: true,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              
              // Route Polyline
              if (isRouteVisible && routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    // Shadow/Border
                    Polyline(
                      points: routePoints,
                      strokeWidth: 8.0,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    // Main route
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5.0,
                      color: const Color(0xFF1976D2),
                      gradientColors: [
                        const Color(0xFF1976D2),
                        const Color(0xFF42A5F5),
                      ],
                    ),
                  ],
                ),
              
              // Markers
              MarkerLayer(
                markers: [
                  // Start location (current position)
                  if (startLocation != null)
                    Marker(
                      point: startLocation!,
                      width: 60,
                      height: 60,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1976D2).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1976D2),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  
                  // End location
                  if (endLocation != null)
                    Marker(
                      point: endLocation!,
                      width: 40,
                      height: 50,
                      child: Icon(
                        Icons.location_on,
                        size: 40,
                        color: const Color(0xFFE53935),
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          
          // Top Status Bar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: MediaQuery.of(context).padding.top + 20,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Route Information Card
          if (showRouteInfo && eta != null && distance != null && !isLoading)
            Positioned(
              top: MediaQuery.of(context).padding.top + 20,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Route info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1976D2).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'FASTEST ROUTE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1976D2),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildQuickStat(
                                icon: Icons.schedule_outlined,
                                value: eta!,
                                label: 'ETA',
                              ),
                              const SizedBox(width: 24),
                              _buildQuickStat(
                                icon: Icons.straighten_outlined,
                                value: distance!,
                                label: 'Distance',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Start Navigation Button
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1976D2),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1976D2).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            // Add navigation start logic here
                          },
                          child: const Icon(
                            Icons.navigation,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Control Panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // My Location Button
                  _buildControlButton(
                    icon: Icons.my_location,
                    onTap: _centerOnUserLocation,
                  ),
                  
                  // Spacer to push buttons to edges
                  const Spacer(),
                  
                  // Recalculate Route Button
                  if (isRouteVisible)
                    _buildControlButton(
                      icon: Icons.refresh,
                      onTap: _recalculateRoute,
                    ),
                  
                  const SizedBox(width: 8),
                  
                  // Center on Route Button
                  if (isRouteVisible)
                    _buildControlButton(
                      icon: Icons.route,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _fitRouteBounds();
                      },
                    ),
                ],
              ),
            ),
          ),

          // Zoom Controls
          Positioned(
            right: 16,
            top: showRouteInfo 
              ? MediaQuery.of(context).padding.top + 140 
              : MediaQuery.of(context).padding.top + 60,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _zoomIn();
                      },
                      child: const Icon(Icons.add, size: 20, color: Colors.black87),
                    ),
                  ),
                ),
                Container(height: 1, width: 44, color: Colors.grey.shade200),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _zoomOut();
                      },
                      child: const Icon(Icons.remove, size: 20, color: Colors.black87),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading Overlay
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1976D2)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading route...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
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

  Widget _buildQuickStat({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                height: 1.0,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Icon(
            icon,
            size: 22,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
