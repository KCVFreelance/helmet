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

class _SignInState extends State<SignIn> {
  final _formKey = GlobalKey<FormState>();
  String email = '';
  String password = '';

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Account not found for this email.')),
          );
          return;
        }
        if (accountData!['pass'] != password) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Incorrect password.')));
          return;
        }
        // Store the helmetId in UserSession for later use
        UserSession.helmetId = foundHelmetId;
        // Navigate to the main app
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const BottomNavBar()),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Logged in as $email (Helmet ID: $foundHelmetId)"),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed: ${e.toString()}")),
        );
      }
    }
  }

  Widget _buildTextField({
    required String label,
    required ValueChanged<String> onChanged,
    bool obscureText = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      decoration: InputDecoration(labelText: label),
      obscureText: obscureText,
      onChanged: onChanged,
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    final logo = CircleAvatar(
      radius: 36,
      backgroundColor: Colors.blue.shade100,
      child: Icon(Icons.shield, size: 36, color: Colors.blue),
    );

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            logo,
            SizedBox(height: 16),
            Text(
              'TOPSHIELD',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            Text(
              'Vehicle Monitoring System',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Login',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Enter your credentials to access your account',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      label: 'Email',
                      onChanged: (val) => email = val,
                      validator: (val) => val != null && val.contains('@')
                          ? null
                          : 'Enter valid email',
                    ),
                    SizedBox(height: 16),
                    Stack(
                      alignment: Alignment.centerRight,
                      children: [
                        _buildTextField(
                          label: 'Password',
                          obscureText: true,
                          onChanged: (val) => password = val,
                          validator: (val) => val != null && val.length >= 6
                              ? null
                              : 'Minimum 6 characters',
                        ),
                        TextButton(
                          onPressed: () async {
                            if (email.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Enter your email first"),
                                ),
                              );
                              return;
                            }
                            try {
                              await FirebaseAuth.instance
                                  .sendPasswordResetEmail(email: email);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Password reset link sent to $email",
                                  ),
                                ),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error: ${e.toString()}"),
                                ),
                              );
                            }
                          },
                          child: Text(
                            'Forgot password?',
                            style: TextStyle(color: Colors.blue, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.black,
                        ),
                        onPressed: _submit,
                        child: Text(
                          'Login',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/signup');
                      },
                      child: Text.rich(
                        TextSpan(
                          text: "Don’t have an account? ",
                          children: [
                            TextSpan(
                              text: "Register",
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
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
}
