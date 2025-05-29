import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:transit/helpers/noti_service.dart';
import 'package:transit/pages/home_page.dart';
import 'package:transit/first_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final notiService = NotiService();
  await notiService.initNotification();
  await notiService.notificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  LocationPermission permission = await Geolocator.checkPermission();

  if (!serviceEnabled) {
    debugPrint("Location services are disabled.");
  } else if (permission == LocationPermission.denied) {
    await Geolocator.requestPermission();
  }

  await Firebase.initializeApp();
  await dotenv.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      behavior: HitTestBehavior.opaque,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PasaHERO',
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          textSelectionTheme: const TextSelectionThemeData(
            cursorColor: Color.fromARGB(255, 58, 58, 58),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(),
          iconTheme: const IconThemeData(
            color: Color.fromARGB(255, 83, 83, 83),
          ),
        ),
        home: const AuthCheck(),
      ),
    );
  }
}

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        Future.microtask(() {
          if (snapshot.hasData) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                  builder: (context) => const HomePage(title: 'HomePage')),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => FirstPage()),
            );
          }
        });

        return const Scaffold(body: SizedBox());
      },
    );
  }
}
