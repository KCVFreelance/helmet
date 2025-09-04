import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class RouteOption {
  final String summary;
  final String distance;
  final String duration;
  final int durationValue; // in seconds
  final List<LatLng> polylinePoints;
  final String routeType;
  final Color color;
  final String description;

  RouteOption({
    required this.summary,
    required this.distance,
    required this.duration,
    required this.durationValue,
    required this.polylinePoints,
    required this.routeType,
    required this.color,
    required this.description,
  });
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  Completer<GoogleMapController> _controller = Completer();
  
  // Replace with your Google Maps API key - keep this secure!
  static const String _apiKey = 'AIzaSyAetVajoczNEi6uSLwwD_vpeHEDIdNgcQs';
  
  // Sample locations (you can modify these)
  static const LatLng _startLocation = LatLng(14.5995, 120.9842); // Manila, Philippines
  static const LatLng _endLocation = LatLng(14.6760, 121.0437);   // Quezon City, Philippines
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  List<RouteOption> _routeOptions = [];
  int _selectedRouteIndex = 0;
  bool _isLoading = false;
  String _selectedRouteType = 'driving';
  String _errorMessage = '';
  bool _showRouteSelection = false;
  
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  
  bool _showRouteOptions = false;

  @override
  void initState() {
    super.initState();
    _startController.text = 'Manila, Philippines';
    _endController.text = 'Quezon City, Philippines';
    _initializeMap();
  }

  void _initializeMap() {
    try {
      _markers = {
        const Marker(
          markerId: MarkerId('start'),
          position: _startLocation,
          infoWindow: InfoWindow(title: 'Start Location', snippet: 'Manila, Philippines'),
          icon: BitmapDescriptor.defaultMarker,
        ),
        const Marker(
          markerId: MarkerId('end'),
          position: _endLocation,
          infoWindow: InfoWindow(title: 'Destination', snippet: 'Quezon City, Philippines'),
          icon: BitmapDescriptor.defaultMarker,
        ),
      };
      
      // Only get directions after a short delay to ensure map is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _getMultipleRoutes();
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing map: $e';
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    try {
      if (!_controller.isCompleted) {
        _controller.complete(controller);
        _mapController = controller;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error creating map: $e';
      });
    }
  }

  Future<void> _getMultipleRoutes() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _routeOptions.clear();
    });

    // Define different route preferences
    List<Map<String, dynamic>> routeConfigs = [
      {
        'avoid': '',
        'name': 'Fastest Route',
        'description': 'Best time',
        'color': Colors.blue,
      },
      {
        'avoid': 'tolls',
        'name': 'Avoid Tolls',
        'description': 'No toll roads',
        'color': Colors.green,
      },
      {
        'avoid': 'highways',
        'name': 'Avoid Highways',
        'description': 'Local roads',
        'color': Colors.orange,
      },
      {
        'avoid': 'ferries',
        'name': 'Avoid Ferries',
        'description': 'No water crossings',
        'color': Colors.purple,
      },
    ];

    for (int i = 0; i < routeConfigs.length; i++) {
      final config = routeConfigs[i];
      await _fetchRoute(config, i);
    }

    // Sort routes by duration (fastest first)
    _routeOptions.sort((a, b) => a.durationValue.compareTo(b.durationValue));
    
    if (_routeOptions.isNotEmpty) {
      _selectRoute(0);
    }

    setState(() {
      _isLoading = false;
      _showRouteSelection = _routeOptions.length > 1;
    });
  }

  Future<void> _fetchRoute(Map<String, dynamic> config, int index) async {
    String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${_startLocation.latitude},${_startLocation.longitude}&'
        'destination=${_endLocation.latitude},${_endLocation.longitude}&'
        'mode=$_selectedRouteType&'
        'key=$_apiKey';
    
    if (config['avoid'].isNotEmpty) {
      url += '&avoid=${config['avoid']}';
    }

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'REQUEST_DENIED') {
          setState(() {
            _errorMessage = 'API Key invalid or Directions API not enabled. Error: ${data['error_message'] ?? 'Unknown error'}';
          });
          return;
        }
        
        if (data['status'] == 'OVER_QUERY_LIMIT') {
          setState(() {
            _errorMessage = 'API quota exceeded. Please check your usage limits.';
          });
          return;
        }
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
          
          final routeOption = RouteOption(
            summary: route['summary'] ?? config['name'],
            distance: leg['distance']['text'],
            duration: leg['duration']['text'],
            durationValue: leg['duration']['value'],
            polylinePoints: polylinePoints,
            routeType: config['name'],
            color: config['color'],
            description: config['description'],
          );
          
          _routeOptions.add(routeOption);
        } else {
          print('No routes found for ${config['name']}: ${data['status']}');
        }
      } else {
        print('HTTP Error for ${config['name']}: ${response.statusCode}');
      }
    } catch (e) {
      print('Network error for ${config['name']}: $e');
      // Don't show error to user for individual route failures
    }
  }

  void _selectRoute(int index) {
    setState(() {
      _selectedRouteIndex = index;
      
      // Update polylines with all routes, highlighting selected one
      _polylines.clear();
      
      for (int i = 0; i < _routeOptions.length; i++) {
        final route = _routeOptions[i];
        _polylines.add(
          Polyline(
            polylineId: PolylineId('route_$i'),
            points: route.polylinePoints,
            color: i == index ? route.color : route.color.withOpacity(0.3),
            width: i == index ? 6 : 4,
            patterns: i == index ? [] : [PatternItem.dash(10), PatternItem.gap(5)],
          ),
        );
      }
    });
  }

  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> points = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble()));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
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
                    "Navigation",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {
                            setState(() {
                              _showRouteOptions = !_showRouteOptions;
                            });
                          },
                          icon: const Icon(Icons.route_outlined, color: Colors.white),
                          iconSize: 22,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.settings_outlined, color: Colors.white),
                          iconSize: 22,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Error Message
            if (_errorMessage.isNotEmpty)
              Container(
                color: Colors.red[50],
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: GoogleFonts.poppins(
                          color: Colors.red[700],
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = '';
                        });
                      },
                      icon: Icon(Icons.close, color: Colors.red[700]),
                    ),
                  ],
                ),
              ),

            // Search and Route Info
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Search Fields
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _startController,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'From',
                              prefixIcon: Icon(Icons.my_location, color: Colors.green[600], size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () {
                          // Swap locations
                          String temp = _startController.text;
                          _startController.text = _endController.text;
                          _endController.text = temp;
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.swap_vert, color: Colors.blue[600], size: 20),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _endController,
                            style: GoogleFonts.poppins(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'To',
                              prefixIcon: Icon(Icons.location_on, color: Colors.red[600], size: 20),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[600]!, Colors.blue[700]!],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: IconButton(
                          onPressed: _getMultipleRoutes,
                          icon: const Icon(Icons.search, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),

                  // Route Options
                  if (_showRouteOptions) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildRouteOption('driving', Icons.directions_car, 'Drive'),
                        _buildRouteOption('walking', Icons.directions_walk, 'Walk'),
                        _buildRouteOption('transit', Icons.directions_transit, 'Transit'),
                        _buildRouteOption('bicycling', Icons.directions_bike, 'Bike'),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Route Selection Cards (Waze-style)
            if (_showRouteSelection && _routeOptions.isNotEmpty)
              Container(
                height: 120,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _routeOptions.length,
                  itemBuilder: (context, index) {
                    final route = _routeOptions[index];
                    final isSelected = index == _selectedRouteIndex;
                    
                    return GestureDetector(
                      onTap: () => _selectRoute(index),
                      child: Container(
                        width: 180,
                        margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isSelected ? route.color.withOpacity(0.1) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? route.color : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: route.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    route.routeType,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      color: isSelected ? route.color : Colors.grey[700],
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              route.duration,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isSelected ? route.color : Colors.grey[800],
                              ),
                            ),
                            Text(
                              route.distance,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              route.description,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Current Route Information
            if (_routeOptions.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _routeOptions[_selectedRouteIndex].color.withOpacity(0.1),
                      _routeOptions[_selectedRouteIndex].color.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _routeOptions[_selectedRouteIndex].color.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildRouteInfo(
                      icon: Icons.straighten_outlined,
                      label: 'Distance',
                      value: _routeOptions[_selectedRouteIndex].distance,
                      color: _routeOptions[_selectedRouteIndex].color,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: _routeOptions[_selectedRouteIndex].color.withOpacity(0.3),
                    ),
                    _buildRouteInfo(
                      icon: Icons.schedule_outlined,
                      label: 'ETA',
                      value: _routeOptions[_selectedRouteIndex].duration,
                      color: Colors.green[700]!,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: _routeOptions[_selectedRouteIndex].color.withOpacity(0.3),
                    ),
                    _buildRouteInfo(
                      icon: Icons.route_outlined,
                      label: 'Route',
                      value: _routeOptions[_selectedRouteIndex].routeType,
                      color: Colors.orange[700]!,
                    ),
                  ],
                ),
              ),

            // Map
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      GoogleMap(
                        onMapCreated: _onMapCreated,
                        initialCameraPosition: const CameraPosition(
                          target: _startLocation,
                          zoom: 12,
                        ),
                        markers: _markers,
                        polylines: _polylines,
                        mapType: MapType.normal,
                        zoomControlsEnabled: false,
                        myLocationButtonEnabled: false,
                        trafficEnabled: true,
                      ),
                      
                      // Loading Overlay
                      if (_isLoading)
                        Container(
                          color: Colors.black.withOpacity(0.3),
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Finding best routes...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Floating Action Buttons
                      Positioned(
                        right: 16,
                        bottom: 80,
                        child: Column(
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'zoom_in',
                              backgroundColor: Colors.white,
                              onPressed: () async {
                                final GoogleMapController controller = await _controller.future;
                                controller.animateCamera(CameraUpdate.zoomIn());
                              },
                              child: Icon(Icons.zoom_in, color: Colors.grey[700]),
                            ),
                            const SizedBox(height: 8),
                            FloatingActionButton.small(
                              heroTag: 'zoom_out',
                              backgroundColor: Colors.white,
                              onPressed: () async {
                                final GoogleMapController controller = await _controller.future;
                                controller.animateCamera(CameraUpdate.zoomOut());
                              },
                              child: Icon(Icons.zoom_out, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                      
                      // Recenter Button
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'recenter',
                          backgroundColor: _routeOptions.isNotEmpty 
                              ? _routeOptions[_selectedRouteIndex].color
                              : Colors.blue[600],
                          onPressed: () async {
                            final GoogleMapController controller = await _controller.future;
                            controller.animateCamera(
                              CameraUpdate.newLatLngBounds(
                                LatLngBounds(
                                  southwest: LatLng(
                                    _startLocation.latitude < _endLocation.latitude 
                                        ? _startLocation.latitude : _endLocation.latitude,
                                    _startLocation.longitude < _endLocation.longitude 
                                        ? _startLocation.longitude : _endLocation.longitude,
                                  ),
                                  northeast: LatLng(
                                    _startLocation.latitude > _endLocation.latitude 
                                        ? _startLocation.latitude : _endLocation.latitude,
                                    _startLocation.longitude > _endLocation.longitude 
                                        ? _startLocation.longitude : _endLocation.longitude,
                                  ),
                                ),
                                100.0,
                              ),
                            );
                          },
                          child: const Icon(Icons.center_focus_strong, color: Colors.white),
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

  Widget _buildRouteOption(String mode, IconData icon, String label) {
    bool isSelected = _selectedRouteType == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRouteType = mode;
          });
          _getMultipleRoutes();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue[600] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey[600],
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteInfo({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
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
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
