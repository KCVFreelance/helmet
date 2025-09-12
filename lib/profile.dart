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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
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
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final monthWord = (monthNum >= 1 && monthNum <= 12)
        ? monthNames[monthNum]
        : parts[0];
    return "$monthWord $day, $year";
  }

  String _calculateSafetyScore() {
    // Return 100 if distance is below minimum threshold (10km)
    if (_totalDistance < 10) return "100";
    if (_totalDistance == 0) return "100";

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
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Info Card
              Container(
                padding: const EdgeInsets.all(24),
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
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue[100]!, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
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
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _isLoading
                              ? Container(
                                  height: 24,
                                  width: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                )
                              : Text(
                                  "$_firstName $_lastName".trim(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _memberSinceDisplay,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit_outlined,
                              color: Colors.blue[700],
                            ),
                            onPressed: _isLoading ? null : _showEditDialog,
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: Icon(Icons.logout, color: Colors.red[400]),
                            tooltip: 'Logout',
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
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Statistics Row with improved design
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      "Alerts",
                      _alertCount.toString(),
                      Icons.notifications_outlined,
                      Colors.red,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Safety Score Card with enhanced design
              Container(
                padding: const EdgeInsets.all(24),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getSafetyScoreColor(),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getSafetyScoreText(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Score Display
                    Row(
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
                                      int.parse(_calculateSafetyScore()) / 100,
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

              const SizedBox(height: 24),

              // Recent Trips Section with improved header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recent Trips",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

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
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // Updated stat card design
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.poppins(
              color: Colors.grey[600],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Updated trip card design
  Widget _buildTripCard(
    String title,
    String date,
    String distance,
    String time,
    Color color,
    IconData icon,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      date,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[600],
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  distance,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    time,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
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
