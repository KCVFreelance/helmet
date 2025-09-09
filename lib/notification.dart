import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String selectedFilter = "All";
  final List<String> filters = ["All", "Safety", "Trip", "Alert"];

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // Helper to parse the "time" string into DateTime for sorting
  DateTime _parseTime(String time) {
    try {
      return DateTime.parse(time); // works if format is "yyyy-MM-dd HH:mm"
    } catch (e) {
      return DateTime.now(); // fallback
    }
  }

  void _loadNotifications() {
    // Listen for alerts
    _dbRef.child("1-000/alert").onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        List<Map<String, dynamic>> temp = [];

        data.forEach((date, alertTypes) {
          (alertTypes as Map).forEach((type, times) {
            (times as Map).forEach((time, value) {
              if (type == "lidar") {
                temp.add({
                  "title": "Safety Alert",
                  "description": "Vehicle detected close by. Drive carefully.",
                  "time": "$date $time",
                  "icon": Icons.car_crash_outlined,
                  "iconColor": Colors.red,
                  "type": "Safety",
                });
              } else if (type == "oSpeed") {
                temp.add({
                  "title": "Overspeeding",
                  "description": "You exceeded the speed limit.",
                  "time": "$date $time",
                  "icon": Icons.speed_outlined,
                  "iconColor": Colors.orange,
                  "type": "Alert",
                });
              }
            });
          });
        });

        setState(() {
          notifications.addAll(temp);
          // Sort newest → oldest
          notifications.sort((a, b) {
            return _parseTime(b["time"]).compareTo(_parseTime(a["time"]));
          });
        });
      }
    });

    // Listen for recentTrips
    _dbRef.child("1-000/recentTrips").onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        List<Map<String, dynamic>> temp = [];
        data.forEach((period, trip) {
          if (trip["distance"].toString() != "0.00") {
            temp.add({
              "title": "Trip Completed",
              "description":
                  "Your $period trip has been recorded - ${trip["distance"]} km in ${trip["tTime"]} minutes",
              "time": trip["date"] ?? "",
              "icon": Icons.directions_car,
              "iconColor": Colors.green,
              "type": "Trip",
            });
          }
        });

        if (temp.isNotEmpty) {
          setState(() {
            notifications.addAll(temp);
            // Sort newest → oldest
            notifications.sort((a, b) {
              return _parseTime(b["time"]).compareTo(_parseTime(a["time"]));
            });
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Apply filter
    final filteredNotifications = notifications.where((notif) {
      return selectedFilter == "All" || notif["type"] == selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[600]!, Colors.blue[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Notifications",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        notifications.clear();
                      });
                    },
                    child: Text(
                      "Clear All",
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // Filter Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: filters.map((filter) {
                  final bool isSelected = selectedFilter == filter;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedFilter = filter;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        filter,
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Notifications
            Expanded(
              child: filteredNotifications.isEmpty
                  ? Center(
                      child: Text(
                        "No notifications yet",
                        style: GoogleFonts.poppins(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredNotifications.length,
                      itemBuilder: (context, index) {
                        final notif = filteredNotifications[index];
                        return _buildNotificationCard(
                          title: notif["title"],
                          description: notif["description"],
                          time: notif["time"],
                          icon: notif["icon"],
                          iconColor: notif["iconColor"],
                          isUnread: true,
                          type: notif["type"],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String description,
    required String time,
    required IconData icon,
    required Color iconColor,
    required bool isUnread,
    required String type,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isUnread
            ? Border.all(color: Colors.blue[200]!, width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [iconColor.withOpacity(0.8), iconColor],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),

                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: isUnread
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        description,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              type,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: iconColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            time,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ],
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
