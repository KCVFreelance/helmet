import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';

class OverspeedService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  void initOverspeedListener() {
    _database.child('1-000/overspeed').onValue.listen((event) async {
      if (event.snapshot.exists) {
        final overspeedData = event.snapshot.value as Map<dynamic, dynamic>;
        if (overspeedData.containsKey('latitude') &&
            overspeedData.containsKey('longitude')) {
          double lat = overspeedData['latitude'];
          double lon = overspeedData['longitude'];
          int? speedLimit = await getSpeedLimit(LatLng(lat, lon));
          print('Location Speed Limit: ${speedLimit ?? "Unknown"} km/h');
          print('Overspeed Data: $overspeedData');
        }
      }
    });
  }

  Future<Map<dynamic, dynamic>?> getOverspeedData() async {
    try {
      final snapshot = await _database.child('1-000/overspeed').get();
      if (snapshot.exists) {
        return snapshot.value as Map<dynamic, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error fetching overspeed data: $e');
      return null;
    }
  }

  Future<int?> getSpeedLimit(LatLng location) async {
    try {
      final query =
          '''
        [out:json];
        way(around:20,${location.latitude},${location.longitude})[highway];
        out body;
        >;
        out skel qt;
      ''';

      final apiUrl =
          'https://overpass-api.de/api/interpreter?data=${Uri.encodeComponent(query)}';
      print('Fetching speed limit from API: $apiUrl');
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        for (var element in elements) {
          if (element['type'] == 'way' && element['tags'] != null) {
            final tags = element['tags'] as Map;

            // Check for maxspeed tag
            if (tags.containsKey('maxspeed')) {
              final maxSpeed = int.tryParse(tags['maxspeed'].toString());
              if (maxSpeed != null) {
                return maxSpeed;
              }
            }

            // Default speed limits based on road type
            final highway = tags['highway'];
            switch (highway) {
              case 'motorway':
                return 100;
              case 'trunk':
              case 'primary':
                return 80;
              case 'secondary':
                return 60;
              case 'residential':
                return 30;
              default:
                return 50;
            }
          }
        }
      }
      return null;
    } catch (e) {
      print('Error fetching speed limit: $e');
      return null;
    }
  }
}
