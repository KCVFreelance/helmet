import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class SignUp extends StatefulWidget {
  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  String firstName = '';
  String lastName = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  String helmetId = '';
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
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
      if (password != confirmPassword) {
        _showSnackBar("Passwords do not match", isError: true);
        return;
      }

      setState(() => _isLoading = true);
      try {
        // First check if helmet ID exists
        final dbRef = FirebaseDatabase.instance.ref();
        final helmetSnapshot = await dbRef.child(helmetId).get();

        if (!helmetSnapshot.exists) {
          _showSnackBar("Helmet ID does not exist. Please enter a valid Helmet ID.", isError: true);
          return;
        }

        // Check if helmet already has an account
        final accountSnapshot = await dbRef.child('$helmetId/accounts').get();
        if (accountSnapshot.exists) {
          _showSnackBar("This Helmet ID is already registered to an account.", isError: true);
          return;
        }

        // If helmet exists and no account, create user
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Save user info to Realtime Database
        final now = DateTime.now();
        final createdDate =
            "${now.month.toString().padLeft(2, '0')}-${now.year}";
        await dbRef.child(helmetId).child('accounts').set({
          'email': email,
          'fname': firstName,
          'lname': lastName,
          'pass': password,
          'createdDate': createdDate,
        });

        _showSnackBar("Account created successfully for $firstName $lastName");
        Navigator.pushReplacementNamed(context, '/signin');
      } on FirebaseAuthException catch (e) {
        _showSnackBar(e.message ?? "Signup failed", isError: true);
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
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    return Scaffold(
      backgroundColor: Colors.blue[50],
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Stack(
                children: [
                  // Background gradient - made responsive
                  Container(
                    height: size.height * 0.28, // Reduced from 0.35
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
                    top: 60, // Adjusted position
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
                    padding: EdgeInsets.symmetric(horizontal: 20), // Reduced padding
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(height: 30), // Reduced
                          // Logo and branding - made more compact
                          Container(
                            width: 60, // Reduced
                            height: 60, // Reduced
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
                              size: 30, // Reduced
                              color: Colors.blue[600],
                            ),
                          ),
                          SizedBox(height: 12), // Reduced
                          Text(
                            'TOPSHIELD',
                            style: TextStyle(
                              fontSize: 24, // Reduced
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            'Vehicle Monitoring System',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14, // Reduced
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          SizedBox(height: 20), // Reduced
                          // Signup form card
                          Container(
                            margin: EdgeInsets.symmetric(horizontal: 4), // Reduced
                            padding: EdgeInsets.all(20), // Reduced
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
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 22, // Reduced
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                  SizedBox(height: 6), // Reduced
                                  Text(
                                    'Please fill in your information to register',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14, // Reduced
                                    ),
                                  ),
                                  SizedBox(height: 20), // Reduced
                                  _buildTextField(
                                    label: 'Helmet ID',
                                    hint: 'Enter your helmet ID',
                                    prefixIcon: Icons.security_outlined,
                                    onChanged: (val) => helmetId = val,
                                    validator: (val) => val!.isEmpty ? 'Helmet ID is required' : null,
                                  ),
                                  SizedBox(height: 14), // Reduced
                                  _buildTextField(
                                    label: 'First Name',
                                    hint: 'Enter first name',
                                    prefixIcon: Icons.person_outline,
                                    onChanged: (val) => firstName = val,
                                    validator: (val) => val!.isEmpty ? 'First name is required' : null,
                                  ),
                                  SizedBox(height: 14),
                                  _buildTextField(
                                    label: 'Last Name',
                                    hint: 'Enter last name',
                                    prefixIcon: Icons.person_outline,
                                    onChanged: (val) => lastName = val,
                                    validator: (val) => val!.isEmpty ? 'Last name is required' : null,
                                  ),
                                  SizedBox(height: 14), // Reduced
                                  _buildTextField(
                                    label: 'Email Address',
                                    hint: 'Enter your email',
                                    prefixIcon: Icons.email_outlined,
                                    onChanged: (val) => email = val,
                                    validator: (val) => val != null && val.contains('@')
                                        ? null
                                        : 'Please enter a valid email',
                                  ),
                                  SizedBox(height: 14), // Reduced
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
                                  SizedBox(height: 14), // Reduced
                                  _buildTextField(
                                    label: 'Confirm Password',
                                    hint: 'Confirm your password',
                                    prefixIcon: Icons.lock_outline,
                                    obscureText: !_isConfirmPasswordVisible,
                                    onChanged: (val) => confirmPassword = val,
                                    validator: (val) => val != null && val.length >= 6
                                        ? null
                                        : 'Password must be at least 6 characters',
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isConfirmPasswordVisible 
                                          ? Icons.visibility_outlined 
                                          : Icons.visibility_off_outlined,
                                        color: Colors.grey[600],
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                        });
                                      },
                                    ),
                                  ),
                                  SizedBox(height: 20), // Reduced
                                  // Register button
                                  Container(
                                    width: double.infinity,
                                    height: 50, // Reduced
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
                                              height: 18, // Reduced
                                              width: 18, // Reduced
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : Text(
                                              'Create Account',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ),
                                  SizedBox(height: 16), // Reduced
                                  // Login link
                                  Center(
                                    child: TextButton(
                                      onPressed: () {
                                        Navigator.pushReplacementNamed(context, '/signin');
                                      },
                                      child: RichText(
                                        text: TextSpan(
                                          text: "Already have an account? ",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14, // Reduced
                                          ),
                                          children: [
                                            TextSpan(
                                              text: "Sign In",
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
                          SizedBox(height: 20), // Reduced
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
