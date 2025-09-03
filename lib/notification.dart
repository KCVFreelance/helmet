import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  String selectedFilter = "All";
  final List<String> filters = ["All", "Safety", "System", "Trip", "Alert"];

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
                    "Notifications",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      letterSpacing: 0.5,
                    ),
                  ),
                  // Row(
                  //   children: [
                  //     Container(
                  //       decoration: BoxDecoration(
                  //         color: Colors.white.withOpacity(0.2),
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //       child: IconButton(
                  //         onPressed: () {},
                  //         icon: const Icon(Icons.mark_email_read_outlined, color: Colors.white),
                  //         iconSize: 22,
                  //       ),
                  //     ),
                  //     const SizedBox(width: 8),
                  //     Container(
                  //       decoration: BoxDecoration(
                  //         color: Colors.white.withOpacity(0.2),
                  //         borderRadius: BorderRadius.circular(12),
                  //       ),
                  //       child: IconButton(
                  //         onPressed: () {},
                  //         icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  //         iconSize: 22,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with unread count
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Stay Updated",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  "Recent Activity",
                                  style: GoogleFonts.poppins(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    "3",
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.blue[50],
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            "Clear All",
                            style: GoogleFonts.poppins(
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Filter Tabs
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: filters.map((filter) => 
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedFilter = filter;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: selectedFilter == filter
                                      ? Colors.blue
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  filter,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: selectedFilter == filter
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: selectedFilter == filter
                                        ? Colors.white
                                        : Colors.grey[600],
                                  ),
                                ),
                              ),
                            ),
                          ).toList(),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Notifications List
                    Expanded(
                      child: ListView(
                        children: [
                          // Today Section
                          _buildSectionHeader("Today"),
                          _buildNotificationCard(
                            title: "Speed Limit Exceeded",
                            description: "You exceeded the speed limit by 15 km/h on Highway 101",
                            time: "2 hours ago",
                            icon: Icons.speed_outlined,
                            iconColor: Colors.red,
                            isUnread: true,
                            type: "Alert",
                          ),
                          _buildNotificationCard(
                            title: "Trip Completed",
                            description: "Your evening commute has been recorded - 8.5 km in 22 minutes",
                            time: "4 hours ago",
                            icon: Icons.check_circle_outline,
                            iconColor: Colors.green,
                            isUnread: true,
                            type: "Trip",
                          ),
                          _buildNotificationCard(
                            title: "Safety Score Updated",
                            description: "Your safety score improved to 85/100. Keep up the good driving!",
                            time: "6 hours ago",
                            icon: Icons.shield_outlined,
                            iconColor: Colors.blue,
                            isUnread: true,
                            type: "Safety",
                          ),

                          const SizedBox(height: 24),

                          // Yesterday Section
                          _buildSectionHeader("Yesterday"),
                          _buildNotificationCard(
                            title: "System Update Available",
                            description: "A new version of Topshield is available with improved features",
                            time: "1 day ago",
                            icon: Icons.system_update_outlined,
                            iconColor: Colors.orange,
                            isUnread: false,
                            type: "System",
                          ),
                          _buildNotificationCard(
                            title: "Weekly Summary Ready",
                            description: "Your weekly driving report is ready. Total distance: 85 km",
                            time: "1 day ago",
                            icon: Icons.assessment_outlined,
                            iconColor: Colors.purple,
                            isUnread: false,
                            type: "Trip",
                          ),

                          const SizedBox(height: 24),

                          // This Week Section
                          _buildSectionHeader("This Week"),
                          _buildNotificationCard(
                            title: "Parking Location Saved",
                            description: "Your vehicle location has been saved at SM Mall of Asia",
                            time: "3 days ago",
                            icon: Icons.local_parking_outlined,
                            iconColor: Colors.green,
                            isUnread: false,
                            type: "System",
                          ),
                          _buildNotificationCard(
                            title: "Speed Alert Settings",
                            description: "Speed alert notifications have been enabled for your safety",
                            time: "5 days ago",
                            icon: Icons.notifications_active_outlined,
                            iconColor: Colors.blue,
                            isUnread: false,
                            type: "Safety",
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
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
                                fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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