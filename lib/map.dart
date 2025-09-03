import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class MapPage extends StatelessWidget {
  const MapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Map - Google Maps"),
        backgroundColor: Colors.blue,
      ),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(14.076314, 121.144600), // Manila
          initialZoom: 13.0,
        ),
        children: [
          TileLayer(
            // Using Google Maps tiles (Note: Check Google's terms of service)
            urlTemplate: kIsWeb
                ? "https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}"
                : "https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}",
            userAgentPackageName: 'com.example.app',
            // Add your API key as a parameter if required by your setup
            additionalOptions: const {
              'key': 'AIzaSyAetVajoczNEi6uSLwwD_vpeHEDIdNgcQs',
            },
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: const LatLng(14.076314, 121.144600),
                width: 80,
                height: 80,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
