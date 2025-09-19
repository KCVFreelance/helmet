import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart'
    as polylines;
import 'package:http/http.dart' as http;
import 'signin.dart'; // Add this import

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

enum TravelMode { driving, walking, motorcycle }

class _MapPageState extends State<MapPage> with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller = Completer();
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  LatLng? startLocation;
  LatLng? endLocation;
  TravelMode _selectedMode = TravelMode.motorcycle;
  String? _duration;
  String? _distance;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  StreamSubscription<Position>? _locationSubscription;
  StreamSubscription<DatabaseEvent>? _deviceLocationSubscription;
  bool _isLoadingRoute = false;
  String? _routeError;
  bool _showRouteInfo = false;
  late AnimationController _slideAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  static const String GOOGLE_MAPS_API_KEY =
      'AIzaSyAetVajoczNEi6uSLwwD_vpeHEDIdNgcQs';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _requestLocationPermission();
    _startLocationUpdates();
    _startDeviceLocationUpdates();
  }

  void _initializeAnimations() {
    _slideAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 1.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.easeInOut,
          ),
        );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseAnimationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _deviceLocationSubscription?.cancel();
    _slideAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  Future<void> _requestLocationPermission() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return;
    }
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        startLocation = LatLng(position.latitude, position.longitude);
        _updateMarkers();
      });
      if (endLocation != null && !_isLoadingRoute) {
        _loadRoute();
      }
    } catch (e) {
      print('Error getting current location: $e');
    }
  }

  void _startLocationUpdates() {
    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          setState(() {
            startLocation = LatLng(position.latitude, position.longitude);
            _updateMarkers();
          });
          if (endLocation != null && !_isLoadingRoute) {
            _loadRoute();
          }
        });
  }

  void _startDeviceLocationUpdates() {
    final helmetId = UserSession.helmetId;
    if (helmetId == null) return;

    _deviceLocationSubscription = _database
        .child('$helmetId/coordinates/gps')
        .onValue
        .listen((event) {
          if (event.snapshot.exists) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            setState(() {
              endLocation = LatLng(
                double.parse(data['latitude'].toString()),
                double.parse(data['longitude'].toString()),
              );
              _updateMarkers();
            });
            if (startLocation != null && !_isLoadingRoute) {
              _loadRoute();
            }
          }
        });
  }

  void _updateMarkers() {
    _markers = {};
    // Only add device location marker, current location is shown by myLocationEnabled
    if (endLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('end'),
          position: endLocation!,
          infoWindow: const InfoWindow(title: 'Device Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
  }

  Future<void> _loadRoute() async {
    if (startLocation == null || endLocation == null || _isLoadingRoute) return;

    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
      _showRouteInfo = false;
    });

    try {
      _polylines = {};
      final polylinePoints = polylines.PolylinePoints();
      final client = http.Client();

      final uri =
          Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
            'origin': '${startLocation!.latitude},${startLocation!.longitude}',
            'destination': '${endLocation!.latitude},${endLocation!.longitude}',
            'mode': _selectedMode == TravelMode.motorcycle
                ? 'driving'
                : _selectedMode.toString().split('.').last,
            'alternatives': 'true',
            'key': GOOGLE_MAPS_API_KEY,
          });

      final result = await client
          .get(uri)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Request timed out');
            },
          );

      client.close();

      if (result.statusCode == 200) {
        final data = json.decode(result.body);

        if (data['status'] == 'OK' &&
            data['routes'] != null &&
            data['routes'].isNotEmpty) {
          _polylines = {};
          for (var i = 0; i < data['routes'].length; i++) {
            final route = data['routes'][i];
            if (route['overview_polyline'] != null) {
              final points = polylinePoints.decodePolyline(
                route['overview_polyline']['points'],
              );

              final polylineCoords = points
                  .map((point) => LatLng(point.latitude, point.longitude))
                  .toList();

              final leg = route['legs'][0];
              final duration = leg['duration']['text'];
              final distance = leg['distance']['text'];

              setState(() {
                if (i == 0) {
                  _duration = duration;
                  _distance = distance;
                }
                _polylines.add(
                  Polyline(
                    polylineId: PolylineId('route_$i'),
                    color: i == 0
                        ? const Color(0xFF4285F4)
                        : const Color(0xFF666666),
                    points: polylineCoords,
                    width: i == 0 ? 6 : 4,
                    patterns: [],
                    onTap: () {
                      setState(() {
                        _duration = duration;
                        _distance = distance;
                        _polylines = _polylines.map((line) {
                          return line.polylineId.value == 'route_$i'
                              ? line.copyWith(
                                  colorParam: const Color(0xFF4285F4),
                                  widthParam: 6,
                                )
                              : line.copyWith(
                                  colorParam: const Color(0xFF666666),
                                  widthParam: 4,
                                );
                        }).toSet();
                      });
                    },
                  ),
                );
              });
            }
          }

          setState(() {
            _routeError = null;
            _showRouteInfo = true;
          });

          _slideAnimationController.forward();
          _focusOnRoute();
        } else {
          final errorMessage =
              data['error_message'] ?? data['status'] ?? 'Unknown error';
          setState(() {
            _routeError = 'Route not found: $errorMessage';
          });
        }
      } else {
        setState(() {
          _routeError = 'Failed to fetch route: ${result.statusCode}';
        });
      }
    } on TimeoutException {
      setState(() {
        _routeError = 'Request timed out. Check your internet connection.';
      });
    } catch (e, stack) {
      debugPrint('Error: $e\nStack: $stack');
      setState(() {
        _routeError = 'Network error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  Future<void> _focusOnRoute() async {
    if (startLocation == null || endLocation == null) return;

    try {
      final GoogleMapController controller = await _controller.future;

      double minLat = startLocation!.latitude < endLocation!.latitude
          ? startLocation!.latitude
          : endLocation!.latitude;
      double maxLat = startLocation!.latitude > endLocation!.latitude
          ? startLocation!.latitude
          : endLocation!.latitude;
      double minLng = startLocation!.longitude < endLocation!.longitude
          ? startLocation!.longitude
          : endLocation!.longitude;
      double maxLng = startLocation!.longitude > endLocation!.longitude
          ? startLocation!.longitude
          : endLocation!.longitude;

      const double padding = 0.005;
      final bounds = LatLngBounds(
        southwest: LatLng(minLat - padding, minLng - padding),
        northeast: LatLng(maxLat + padding, maxLng + padding),
      );

      await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (e) {
      debugPrint('Error focusing on route: $e');
    }
  }

  void _retryLoadRoute() {
    if (!_isLoadingRoute) {
      _slideAnimationController.reset();
      _loadRoute();
    }
  }

  Widget _buildTravelModeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
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
          _buildModeButton(
            TravelMode.motorcycle,
            Icons.two_wheeler,
            'Motorcycle',
          ),
          _buildModeButton(TravelMode.driving, Icons.directions_car, 'Car'),
          _buildModeButton(TravelMode.walking, Icons.directions_walk, 'Walk'),
        ],
      ),
    );
  }

  Widget _buildModeButton(TravelMode mode, IconData icon, String label) {
    final isSelected = _selectedMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (!isSelected) {
            setState(() {
              _selectedMode = mode;
            });
            _loadRoute();
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4285F4) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfo() {
    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_duration != null && _distance != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedMode == TravelMode.walking
                            ? Icons.directions_walk
                            : _selectedMode == TravelMode.motorcycle
                            ? Icons.two_wheeler
                            : Icons.directions_car,
                        color: const Color(0xFF4285F4),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _duration!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _distance!,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap on alternative routes to select',
                style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF4285F4),
                      ),
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Finding best route...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Positioned(
      top: 100,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _routeError!,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryLoadRoute,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4285F4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: startLocation ?? const LatLng(14.0763684, 121.1446282),
              zoom: 17,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            mapType: MapType.normal,
            trafficEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            tiltGesturesEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
            },
            style: '''
              [
                {
                  "featureType": "poi",
                  "elementType": "labels",
                  "stylers": [{"visibility": "off"}]
                }
              ]
            ''',
          ),

          // Top travel mode selector
          SafeArea(child: _buildTravelModeSelector()),

          // My location button
          Positioned(
            bottom: _showRouteInfo ? 220 : 100,
            right: 20,
            child: FloatingActionButton(
              onPressed: _focusOnRoute,
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF4285F4),
              elevation: 4,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Loading indicator
          if (_isLoadingRoute) _buildLoadingIndicator(),

          // Error message
          if (_routeError != null && !_isLoadingRoute) _buildErrorMessage(),

          // Bottom route info panel
          if (_showRouteInfo && startLocation != null && endLocation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(child: _buildRouteInfo()),
            ),
        ],
      ),
    );
  }
}
