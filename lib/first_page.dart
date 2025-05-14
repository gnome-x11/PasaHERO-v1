import 'package:flutter/material.dart';
import 'second_page.dart';
import 'package:google_fonts/google_fonts.dart';

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  _FirstPageState createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 150),
              Center(
                child: Image.asset(
                  'lib/assets/small_logo.png',
                  width: 200,
                  height: 200,
                ),
              ),
              const SizedBox(height: 160),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  children: [
                    Text(
                      "Muntinlupa Jeep Route App",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        color: const Color.fromARGB(255, 37, 37, 37),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 50.0),
                child: Column(
                  children: [
                    Text(
                      "Let’s navigate and explore the streets of Muntinlupa City.",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: Color.fromARGB(255, 37, 37, 37),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const SecondPage(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = 0.0;
                        const end = 1.0;
                        const curve = Curves.easeInOut;

                        var fadeAnimation = CurvedAnimation(
                          parent: animation,
                          curve: curve,
                        );

                        return FadeTransition(
                          opacity: Tween(begin: begin, end: end)
                              .animate(fadeAnimation),
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 500),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF04BE62),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 90, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Start Navigating",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 60),
              const Text(
                "Project by SPaDe \n Designed and Developed by A.D.R",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Arial',
                  fontSize: 13,
                  fontWeight: FontWeight.normal,
                  color: Color.fromARGB(183, 131, 131, 131),
                ),
              ),
              const SizedBox(height: 2),
              const Center(
                child: Text(
                  'All rights reserved © 2025',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color.fromARGB(183, 131, 131, 131),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
