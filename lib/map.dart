import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? _mapController;
  Completer<GoogleMapController> _controller = Completer();
  
  // Replace with your Google Maps API key - keep this secure!
  static const String _apiKey = 'AIzaSyAetVajoczNEi6uSLwwD_vpeHEDIdNgcQs'; // Replace with your actual API key
  
  // Sample locations (you can modify these)
  static const LatLng _startLocation = LatLng(14.5995, 120.9842); // Manila, Philippines
  static const LatLng _endLocation = LatLng(14.6760, 121.0437);   // Quezon City, Philippines
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  String _distance = '';
  String _duration = '';
  bool _isLoading = false;
  String _selectedRouteType = 'driving';
  String _errorMessage = '';
  
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
          _getDirections();
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

  Future<void> _getDirections() async {
    if (_apiKey == 'YOUR_API_KEY_HERE') {
      setState(() {
        _errorMessage = 'Please set your Google Maps API key';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final String url = 'https://maps.googleapis.com/maps/api/directions/json?'
        'origin=${_startLocation.latitude},${_startLocation.longitude}&'
        'destination=${_endLocation.latitude},${_endLocation.longitude}&'
        'mode=$_selectedRouteType&'
        'key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          setState(() {
            _distance = leg['distance']['text'];
            _duration = leg['duration']['text'];
          });
          
          // Decode polyline
          final polylinePoints = _decodePolyline(route['overview_polyline']['points']);
          
          setState(() {
            _polylines = {
              Polyline(
                polylineId: const PolylineId('route'),
                points: polylinePoints,
                color: Colors.blue,
                width: 5,
                patterns: [],
              ),
            };
          });
        } else {
          setState(() {
            _errorMessage = 'No routes found: ${data['status']}';
          });
        }
      } else {
        setState(() {
          _errorMessage = 'HTTP Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting directions: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
                          onPressed: _getDirections,
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

            // Route Information Card
            if (_distance.isNotEmpty && _duration.isNotEmpty)
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[50]!, Colors.blue[100]!],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildRouteInfo(
                      icon: Icons.straighten_outlined,
                      label: 'Distance',
                      value: _distance,
                      color: Colors.blue[700]!,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.blue[300],
                    ),
                    _buildRouteInfo(
                      icon: Icons.schedule_outlined,
                      label: 'ETA',
                      value: _duration,
                      color: Colors.green[700]!,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.blue[300],
                    ),
                    _buildRouteInfo(
                      icon: Icons.speed_outlined,
                      label: 'Mode',
                      value: _selectedRouteType.toUpperCase(),
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
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                          backgroundColor: Colors.blue[600],
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
          _getDirections();
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
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
