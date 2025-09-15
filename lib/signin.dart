import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'navBar.dart';

// Add a global session class to hold the current helmet ID
class UserSession {
  static String? helmetId;
}

class SignIn extends StatefulWidget {
  @override
  _SignInState createState() => _SignInState();
}

class _SignInState extends State<SignIn> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        // Search for helmet ID by email in the database
        final dbRef = FirebaseDatabase.instance.ref();
        final snapshot = await dbRef.get();
        String? foundHelmetId;
        Map<String, dynamic>? accountData;
        for (final child in snapshot.children) {
          final accounts = child.child('accounts');
          if (accounts.exists) {
            final data = Map<String, dynamic>.from(accounts.value as Map);
            if (data['email'] == email) {
              foundHelmetId = child.key;
              accountData = data;
              break;
            }
          }
        }
        if (foundHelmetId == null) {
          _showSnackBar('Account not found for this email.', isError: true);
          return;
        }
        if (accountData!['pass'] != password) {
          _showSnackBar('Incorrect password.', isError: true);
          return;
        }
        // Store the helmetId in UserSession for later use
        UserSession.helmetId = foundHelmetId;
        // Navigate to the main app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BottomNavBar()),
        );
        _showSnackBar("Welcome back! Logged in as $email");
      } catch (e) {
        _showSnackBar("Login failed: ${e.toString()}", isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    IconData? prefixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w500),
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: prefixIcon != null 
            ? Icon(prefixIcon, color: Colors.blue[600])
            : null,
          suffixIcon: suffixIcon,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        obscureText: obscureText,
        onChanged: onChanged,
        validator: validator,
        style: TextStyle(fontSize: 16, color: Colors.grey[800]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.blue[50],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            height: size.height,
            child: Stack(
              children: [
                // Background gradient
                Container(
                  height: size.height * 0.4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue[600]!,
                        Colors.blue[800]!,
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                ),
                // Floating circles for decoration
                Positioned(
                  top: -50,
                  right: -50,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                Positioned(
                  top: 100,
                  left: -30,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                // Main content
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: 60),
                        // Logo and branding
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.shield_outlined,
                            size: 40,
                            color: Colors.blue[600],
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'TOPSHIELD',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        Text(
                          'Vehicle Monitoring System',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        SizedBox(height: 40),
                        // Login form card
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 8),
                          padding: EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.15),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome Back',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Please sign in to your account',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 32),
                                _buildTextField(
                                  label: 'Email Address',
                                  hint: 'Enter your email',
                                  prefixIcon: Icons.email_outlined,
                                  onChanged: (val) => email = val,
                                  validator: (val) => val != null && val.contains('@')
                                      ? null
                                      : 'Please enter a valid email',
                                ),
                                SizedBox(height: 20),
                                _buildTextField(
                                  label: 'Password',
                                  hint: 'Enter your password',
                                  prefixIcon: Icons.lock_outline,
                                  obscureText: !_isPasswordVisible,
                                  onChanged: (val) => password = val,
                                  validator: (val) => val != null && val.length >= 6
                                      ? null
                                      : 'Password must be at least 6 characters',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible 
                                        ? Icons.visibility_outlined 
                                        : Icons.visibility_off_outlined,
                                      color: Colors.grey[600],
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible = !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                                SizedBox(height: 12),
                                Center(
                                  child: TextButton(
                                    onPressed: () async {
                                      if (email.isEmpty) {
                                        _showSnackBar("Please enter your email first", isError: true);
                                        return;
                                      }
                                      try {
                                        await FirebaseAuth.instance
                                            .sendPasswordResetEmail(email: email);
                                        _showSnackBar("Password reset link sent to $email");
                                      } catch (e) {
                                        _showSnackBar("Error: ${e.toString()}", isError: true);
                                      }
                                    },
                                    child: Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: Colors.blue[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 24),
                                // Login button
                                Container(
                                  width: double.infinity,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue[600]!, Colors.blue[700]!],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.blue.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: _isLoading ? null : _submit,
                                    child: _isLoading
                                        ? SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : Text(
                                            'Sign In',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                SizedBox(height: 24),
                                // Register link
                                Center(
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(context, '/signup');
                                    },
                                    child: RichText(
                                      text: TextSpan(
                                        text: "Don't have an account? ",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 15,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: "Sign Up",
                                            style: TextStyle(
                                              color: Colors.blue[600],
                                              fontWeight: FontWeight.bold,
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
                        ),
                        SizedBox(height: 40),
                      ],
                    ),
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
