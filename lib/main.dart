import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'navBar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyBcWBAJ2lCy9wOFx-kONqoxkTO9ey0E9Us",
        authDomain: "helmet-858a5.firebaseapp.com",
        databaseURL: "https://helmet-858a5-default-rtdb.firebaseio.com",
        projectId: "helmet-858a5",
        storageBucket: "helmet-858a5.firebasestorage.app",
        messagingSenderId: "1013766552572",
        appId: "1:1013766552572:web:6887e6500b7e8a18da5079",
        measurementId: "G-VCMY69XB2P",
      ),
    );
  } catch (e) {
    print("Firebase initialization error: $e");
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Topshield',
      theme: ThemeData(textTheme: GoogleFonts.poppinsTextTheme()),
      home: const BottomNavBar(),
    );
  }
}
