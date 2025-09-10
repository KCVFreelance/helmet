import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'navBar.dart';
import 'signin.dart';
import 'signup.dart';

const firebaseWebOptions = FirebaseOptions(
  apiKey: "AIzaSyBcWBAJ2lCy9wOFx-kONqoxkTO9ey0E9Us",
  authDomain: "helmet-858a5.firebaseapp.com",
  databaseURL: "https://helmet-858a5-default-rtdb.firebaseio.com",
  projectId: "helmet-858a5",
  storageBucket: "helmet-858a5.appspot.com",
  messagingSenderId: "1013766552572",
  appId: "1:1013766552572:web:6887e6500b7ef18da5079",
  measurementId: "G-VCMY69XB2P",
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(options: firebaseWebOptions);
  } else {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Topshield',
      theme: ThemeData(textTheme: GoogleFonts.poppinsTextTheme()),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasData) {
            // ✅ Go to BottomNavBar instead of HomePage
            return const BottomNavBar();
          }
          return SignIn();
        },
      ),
      routes: {
        '/navbar': (context) => const BottomNavBar(),
        '/signin': (context) => SignIn(),
        '/signup': (context) => SignUp(),
      },
    );
  }
}
