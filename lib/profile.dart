import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signin.dart'; // Import to access UserSession

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _firstName = "Loading...";
  String _lastName = "";
  String _createdDate = "";
  bool _isLoading = true;
  bool _isSaving = false;

  String? get _helmetId => UserSession.helmetId;

  Map<String, dynamic>? _morningTrip;
  Map<String, dynamic>? _eveningTrip;

  int _alertCount = 0;
  double _totalDistance = 0.0;

  StreamSubscription<DatabaseEvent>? _coordSubscription;
  StreamSubscription<DatabaseEvent>? _alertSubscription;

  @override
  void initState() {
    super.initState();
    _listenToUserData();
    _fetchUserData();
  }

  @override
  void dispose() {
    _coordSubscription?.cancel();
    _alertSubscription?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  void _listenToUserData() {
    final helmetId = _helmetId;
    if (helmetId == null) return;
    // Listen for coordinates changes
    _coordSubscription = _database
        .child('$helmetId/coordinates')
        .onValue
        .listen((event) {
          double totalDistance = 0.0;
          if (event.snapshot.exists) {
            final coordData = Map<String, dynamic>.from(
              event.snapshot.value as Map,
            );
            for (final dateEntry in coordData.values) {
              if (dateEntry is Map) {
                for (final timeEntry in dateEntry.values) {
                  if (timeEntry is Map && timeEntry['tDistance'] != null) {
                    final tDist = timeEntry['tDistance'];
                    if (tDist is double)
                      totalDistance += tDist;
                    else if (tDist is int)
                      totalDistance += tDist.toDouble();
                    else if (tDist is String)
                      totalDistance += double.tryParse(tDist) ?? 0.0;
                  }
                }
              }
            }
          }
          setState(() {
            _totalDistance = totalDistance;
          });
        });
    // Listen for alert changes
    _alertSubscription = _database.child('$helmetId/alert').onValue.listen((
      event,
    ) {
      int alertCount = 0;
      if (event.snapshot.exists) {
        final alertData = Map<String, dynamic>.from(
          event.snapshot.value as Map,
        );
        for (final dateEntry in alertData.values) {
          if (dateEntry is Map) {
            if (dateEntry['lidar'] is Map) {
              final lidar = Map<String, dynamic>.from(dateEntry['lidar']);
              alertCount += lidar.values.where((v) => v == 1).length;
            }
            if (dateEntry['oSpeed'] is Map) {
              final oSpeed = Map<String, dynamic>.from(dateEntry['oSpeed']);
              alertCount += oSpeed.values.where((v) => v == 1).length;
            }
          }
        }
      }
      setState(() {
        _alertCount = alertCount;
      });
    });
  }

  Future<void> _fetchUserData() async {
    try {
      final helmetId = _helmetId;
      int alertCount = 0;
      double totalDistance = 0.0;
      if (helmetId != null) {
        // Fetch all tDistance from coordinates
        final coordSnapshot = await _database
            .child('$helmetId/coordinates')
            .get();
        if (coordSnapshot.exists) {
          final coordData = Map<String, dynamic>.from(
            coordSnapshot.value as Map,
          );
          for (final dateEntry in coordData.values) {
            if (dateEntry is Map) {
              for (final timeEntry in dateEntry.values) {
                if (timeEntry is Map && timeEntry['tDistance'] != null) {
                  final tDist = timeEntry['tDistance'];
                  if (tDist is double)
                    totalDistance += tDist;
                  else if (tDist is int)
                    totalDistance += tDist.toDouble();
                  else if (tDist is String)
                    totalDistance += double.tryParse(tDist) ?? 0.0;
                }
              }
            }
          }
        }
        // Alerts logic
        final alertSnapshot = await _database.child('$helmetId/alert').get();
        if (alertSnapshot.exists) {
          final alertData = Map<String, dynamic>.from(
            alertSnapshot.value as Map,
          );
          for (final dateEntry in alertData.values) {
            if (dateEntry is Map) {
              if (dateEntry['lidar'] is Map) {
                final lidar = Map<String, dynamic>.from(dateEntry['lidar']);
                alertCount += lidar.values.where((v) => v == 1).length;
              }
              if (dateEntry['oSpeed'] is Map) {
                final oSpeed = Map<String, dynamic>.from(dateEntry['oSpeed']);
                alertCount += oSpeed.values.where((v) => v == 1).length;
              }
            }
          }
        }
        // Get user data
        final snapshot = await _database.child('$helmetId/accounts').get();
        Map<String, dynamic>? morningTrip;
        Map<String, dynamic>? eveningTrip;
        final tripsSnapshot = await _database
            .child('$helmetId/recentTrips')
            .get();
        if (tripsSnapshot.exists) {
          final tripsData = Map<String, dynamic>.from(
            tripsSnapshot.value as Map,
          );
          if (tripsData['morning'] != null) {
            morningTrip = Map<String, dynamic>.from(
              tripsData['morning'] as Map,
            );
          }
          if (tripsData['evening'] != null) {
            eveningTrip = Map<String, dynamic>.from(
              tripsData['evening'] as Map,
            );
          }
        }
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            _firstName = data['fname'] ?? "User";
            _lastName = data['lname'] ?? "";
            _createdDate = data['createdDate'] ?? "";
            _morningTrip = morningTrip;
            _eveningTrip = eveningTrip;
            _alertCount = alertCount;
            _totalDistance = totalDistance;
            _isLoading = false;
          });
        } else {
          setState(() {
            _firstName = "User";
            _lastName = "Not Found";
            _createdDate = "";
            _morningTrip = morningTrip;
            _eveningTrip = eveningTrip;
            _alertCount = alertCount;
            _totalDistance = totalDistance;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _firstName = "Error";
        _lastName = "Loading User";
        _createdDate = "";
        _morningTrip = null;
        _eveningTrip = null;
        _alertCount = 0;
        _totalDistance = 0.0;
        _isLoading = false;
      });
      print("Error fetching user data: $e");
    }
  }

  Future<void> _updateUserData(String firstName, String lastName) async {
    setState(() {
      _isSaving = true;
    });
    try {
      final helmetId = _helmetId;
      if (helmetId == null) {
        setState(() {
          _isSaving = false;
        });
        return;
      }
      await _database.child('$helmetId/accounts').update({
        'fname': firstName,
        'lname': lastName,
      });
      setState(() {
        _firstName = firstName;
        _lastName = lastName;
        _isSaving = false;
      });
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Profile updated successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update profile. Please try again.',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      print("Error updating user data: $e");
    }
  }

  void _showEditDialog() {
    _firstNameController.text = _firstName;
    _lastNameController.text = _lastName;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'Edit Profile',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              content: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        labelStyle: GoogleFonts.poppins(
                          color: Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue[600]!),
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: Colors.grey[600],
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      style: GoogleFonts.poppins(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'First name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        labelStyle: GoogleFonts.poppins(
                          color: Colors.grey[600],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue[600]!),
                        ),
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: Colors.grey[600],
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      style: GoogleFonts.poppins(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Last name is required';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSaving
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            _updateUserData(
                              _firstNameController.text.trim(),
                              _lastNameController.text.trim(),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Save',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String get _memberSinceDisplay {
    if (_createdDate.isEmpty) return "Member since Unknown";
    final parts = _createdDate.split('-');
    if (parts.length != 2) return "Member since Unknown";
    final monthNum = int.tryParse(parts[0]);
    final year = parts[1];
    if (monthNum == null) return "Member since Unknown";
    const monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthWord = (monthNum >= 1 && monthNum <= 12)
        ? monthNames[monthNum]
        : '';
    if (monthWord.isEmpty) return "Member since $year";
    return "Member since $monthWord $year";
  }

  String _formatTravelTime(dynamic tTime) {
    if (tTime == null) return "-";
    int totalSeconds = 0;
    if (tTime is int) {
      totalSeconds = tTime;
    } else if (tTime is String) {
      totalSeconds = int.tryParse(tTime) ?? 0;
    }

    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      if (minutes == 0) {
        return "${hours}h";
      } else {
        return "${hours}h ${minutes}m";
      }
    } else if (minutes > 0) {
      if (seconds == 0) {
        return "${minutes}m";
      } else {
        return "${minutes}m ${seconds}s";
      }
    } else {
      return "${seconds}s";
    }
  }

  String _formatTripDate(String? date) {
    if (date == null || date.isEmpty) return "-";
    final parts = date.split('-');
    if (parts.length != 3) return date;
    final monthNum = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = parts[2];
    if (monthNum == null || day == null) return date;
    const monthNames = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final monthWord = (monthNum >= 1 && monthNum <= 12)
        ? monthNames[monthNum]
        : parts[0];
    return "$monthWord $day, $year";
  }

  String _calculateSafetyScore() {
    // If both distance and alerts are zero, return 100
    if (_totalDistance == 0 && _alertCount == 0) return "100";
    // If distance is zero but there are alerts, score should be 0
    if (_totalDistance == 0 && _alertCount > 0) return "0";
    // Return 100 if distance is below minimum threshold (10km)
    if (_totalDistance < 0) return "100";

    // Calculate alerts per kilometer
    double alertsPerKm = _alertCount / _totalDistance;

    // Apply formula: Score = 100 - (alerts_per_km * K)
    // Using K = 1000 as scaling factor
    int score = 100 - (alertsPerKm * 1000).round();

    // Ensure score doesn't go below 0 or above 100
    if (score < 0) return "0";
    if (score > 100) return "100";
    return score.toString();
  }

  String _getSafetyScoreText() {
    final score = int.parse(_calculateSafetyScore());
    if (score >= 90) return "Excellent";
    if (score >= 70) return "Good";
    if (score >= 50) return "Fair";
    return "Poor";
  }

  Color _getSafetyScoreColor() {
    final score = int.parse(_calculateSafetyScore());
    if (score >= 90) return Colors.green[600]!;
    if (score >= 70) return Colors.blue[600]!;
    if (score >= 50) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 16 : 24,
            vertical: isSmallScreen ? 20 : 32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Info Card - Responsive Layout
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Main Profile Row (without action buttons)
                    Row(
                      children: [
                        // Avatar
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.blue[100]!,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: isSmallScreen ? 32 : 40,
                            backgroundColor: Colors.blue,
                            child: _isLoading
                                ? SizedBox(
                                    width: isSmallScreen ? 16 : 20,
                                    height: isSmallScreen ? 16 : 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _firstName.isNotEmpty
                                        ? _firstName[0].toUpperCase()
                                        : "U",
                                    style: GoogleFonts.poppins(
                                      fontSize: isSmallScreen ? 24 : 32,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(width: isSmallScreen ? 12 : 20),

                        // User Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _isLoading
                                  ? Container(
                                      height: isSmallScreen ? 20 : 24,
                                      width: isSmallScreen ? 120 : 150,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    )
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        "$_firstName $_lastName".trim(),
                                        style: GoogleFonts.poppins(
                                          fontSize: isSmallScreen ? 18 : 22,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[800],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                              SizedBox(height: isSmallScreen ? 4 : 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _memberSinceDisplay,
                                      style: GoogleFonts.poppins(
                                        fontSize: isSmallScreen ? 12 : 14,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 20),

                    // Action Buttons Row - Now below the profile info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Edit Profile Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _showEditDialog,
                            icon: Icon(
                              Icons.edit_outlined,
                              size: isSmallScreen ? 18 : 20,
                            ),
                            label: Text(
                              'Edit Profile',
                              style: GoogleFonts.poppins(
                                fontSize: isSmallScreen ? 13 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),

                        SizedBox(width: isSmallScreen ? 12 : 16),

                        // Logout Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              UserSession.helmetId = null;
                              try {
                                await FirebaseAuth.instance.signOut();
                              } catch (_) {}
                              if (mounted) {
                                Navigator.of(context).pushNamedAndRemoveUntil(
                                  '/signin',
                                  (route) => false,
                                );
                              }
                            },
                            icon: Icon(
                              Icons.logout,
                              size: isSmallScreen ? 18 : 20,
                            ),
                            label: Text(
                              'Logout',
                              style: GoogleFonts.poppins(
                                fontSize: isSmallScreen ? 13 : 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[400],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 12 : 16,
                                vertical: isSmallScreen ? 10 : 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: isSmallScreen ? 16 : 24),

              // Statistics Row with responsive spacing
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      "Total Distance",
                      _isLoading
                          ? "..."
                          : "${_totalDistance.toStringAsFixed(2)} km",
                      Icons.route_outlined,
                      Colors.blue,
                      isSmallScreen,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    child: _buildStatCard(
                      "Alerts",
                      _alertCount.toString(),
                      Icons.notifications_outlined,
                      Colors.red,
                      isSmallScreen,
                    ),
                  ),
                ],
              ),

              SizedBox(height: isSmallScreen ? 16 : 24),

              // Safety Score Card
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getSafetyScoreColor().withOpacity(0.1),
                      _getSafetyScoreColor().withOpacity(0.2),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getSafetyScoreColor().withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Safety Score",
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 8 : 12,
                            vertical: isSmallScreen ? 4 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getSafetyScoreColor(),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getSafetyScoreText(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: isSmallScreen ? 16 : 20),

                    // Score Display - Responsive Layout
                    isSmallScreen
                        ? Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      _calculateSafetyScore(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: _getSafetyScoreColor(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "/ 100",
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Column(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: LinearProgressIndicator(
                                      value:
                                          int.parse(_calculateSafetyScore()) /
                                          100,
                                      minHeight: 12,
                                      backgroundColor: Colors.grey[300],
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        _getSafetyScoreColor(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _getSafetyScoreText() == "Excellent"
                                        ? "Excellent driving behavior! Keep up the safe habits."
                                        : _getSafetyScoreText() == "Good"
                                        ? "Good driving behavior! Keep improving."
                                        : _getSafetyScoreText() == "Fair"
                                        ? "Fair driving record. Focus on reducing alerts."
                                        : "Safety needs improvement. Drive carefully.",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.grey[700],
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      _calculateSafetyScore(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: _getSafetyScoreColor(),
                                      ),
                                    ),
                                    Text(
                                      "out of 100",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: LinearProgressIndicator(
                                        value:
                                            int.parse(_calculateSafetyScore()) /
                                            100,
                                        minHeight: 12,
                                        backgroundColor: Colors.grey[300],
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              _getSafetyScoreColor(),
                                            ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _getSafetyScoreText() == "Excellent"
                                          ? "Your driving behavior is excellent! Keep up the safe driving habits."
                                          : _getSafetyScoreText() == "Good"
                                          ? "Good driving behavior! Keep improving for excellence."
                                          : _getSafetyScoreText() == "Fair"
                                          ? "Fair driving record. Focus on reducing alerts."
                                          : "Safety needs improvement. Please drive more carefully.",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.grey[700],
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),

              SizedBox(height: isSmallScreen ? 16 : 24),

              // Recent Trips Section
              Text(
                "Recent Trips",
                style: GoogleFonts.poppins(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),

              SizedBox(height: isSmallScreen ? 12 : 16),

              // Trip History Cards
              _buildTripCard(
                "Morning Commute",
                _morningTrip != null && _morningTrip!["date"] != null
                    ? _formatTripDate(_morningTrip!["date"])
                    : "-",
                _morningTrip != null && _morningTrip!["distance"] != null
                    ? "${_morningTrip!["distance"]} km"
                    : "-",
                _formatTravelTime(
                  _morningTrip != null ? _morningTrip!["tTime"] : null,
                ),
                Colors.blue,
                Icons.wb_sunny_outlined,
                isSmallScreen,
              ),
              _buildTripCard(
                "Evening Drive",
                _eveningTrip != null && _eveningTrip!["date"] != null
                    ? _formatTripDate(_eveningTrip!["date"])
                    : "-",
                _eveningTrip != null && _eveningTrip!["distance"] != null
                    ? "${_eveningTrip!["distance"]} km"
                    : "-",
                _formatTravelTime(
                  _eveningTrip != null ? _eveningTrip!["tTime"] : null,
                ),
                Colors.orange,
                Icons.nightlight_outlined,
                isSmallScreen,
              ),

              SizedBox(height: isSmallScreen ? 16 : 20),
            ],
          ),
        ),
      ),
    );
  }

  // Updated stat card design with responsive sizing
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
          ),
          SizedBox(height: isSmallScreen ? 8 : 12),
          FittedBox(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: color,
                fontSize: isSmallScreen ? 16 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(height: isSmallScreen ? 2 : 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Updated trip card design with responsive sizing
  Widget _buildTripCard(
    String title,
    String date,
    String distance,
    String time,
    Color color,
    IconData icon,
    bool isSmallScreen,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isSmallScreen ? 20 : 24,
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isSmallScreen ? 4 : 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        date,
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 11 : 13,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 6 : 8,
                  vertical: isSmallScreen ? 2 : 4,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  distance,
                  style: GoogleFonts.poppins(
                    fontSize: isSmallScreen ? 12 : 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              SizedBox(height: isSmallScreen ? 4 : 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 12,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    time,
                    style: GoogleFonts.poppins(
                      fontSize: isSmallScreen ? 11 : 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
