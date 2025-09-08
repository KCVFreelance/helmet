import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class SignUp extends StatefulWidget {
  @override
  _SignUpState createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final _formKey = GlobalKey<FormState>();
  String firstName = '';
  String lastName = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  String helmetId = '';

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (password != confirmPassword) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Passwords do not match")));
        return;
      }

      try {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Save user info to Realtime Database
        final dbRef = FirebaseDatabase.instance.ref();
        await dbRef.child(helmetId).child('accounts').set({
          'email': email,
          'fname': firstName,
          'lname': lastName,
          'pass': password,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Account created for $firstName $lastName")),
        );

        Navigator.pushReplacementNamed(context, '/signin');
      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message ?? "Signup failed")));
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
                        'Create an Account',
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
                        'Enter your information to register',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      label: 'Helmet ID',
                      onChanged: (val) => helmetId = val,
                      validator: (val) => val!.isEmpty ? 'Required' : null,
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            label: 'First Name',
                            onChanged: (val) => firstName = val,
                            validator: (val) =>
                                val!.isEmpty ? 'Required' : null,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            label: 'Last Name',
                            onChanged: (val) => lastName = val,
                            validator: (val) =>
                                val!.isEmpty ? 'Required' : null,
                          ),
                        ),
                      ],
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
                    _buildTextField(
                      label: 'Password',
                      onChanged: (val) => password = val,
                      obscureText: true,
                      validator: (val) => val != null && val.length >= 6
                          ? null
                          : 'Minimum 6 characters',
                    ),
                    SizedBox(height: 16),
                    _buildTextField(
                      label: 'Confirm Password',
                      onChanged: (val) => confirmPassword = val,
                      obscureText: true,
                      validator: (val) => val != null && val.length >= 6
                          ? null
                          : 'Minimum 6 characters',
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
                          'Register',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacementNamed(context, '/signin');
                      },
                      child: Text.rich(
                        TextSpan(
                          text: "Already have an account? ",
                          children: [
                            TextSpan(
                              text: "Login",
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
