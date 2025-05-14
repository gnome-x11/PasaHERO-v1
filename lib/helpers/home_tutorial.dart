import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/noti_service.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';

class HomeTutorial {
  final BuildContext context;
  final GlobalKey logoIconKey;
  final GlobalKey searchToggleKey;
  final GlobalKey trafficToggleKey;
  final GlobalKey locationButtonKey;
  late final ConfettiController _confettiController;

  HomeTutorial({
    required this.context,
    required this.logoIconKey,
    required this.searchToggleKey,
    required this.trafficToggleKey,
    required this.locationButtonKey,
  });

  Future<void> showIfFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('home_tutorial_shown') ?? true;

    if (isFirstLaunch) {
      await prefs.setBool('home_tutorial_shown', false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _showTutorial());
    }
  }

  void _showWelcomeModal() {
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _confettiController.play();
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          backgroundColor: Colors.white,
          child: Stack(
            children: [
              Positioned.fill(
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  emissionFrequency: 0.05,
                  numberOfParticles: 50,
                  colors: const [
                    Colors.red,
                    Colors.blue,
                    Colors.green,
                    Colors.yellow
                  ],
                  shouldLoop: false,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Welcome to PasaHERO!",
                      style: GoogleFonts.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "You are all set! Explore the app and enjoy the experience. "
                      "If you need any help, check the menu.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        NotiService().showNotification(
                            title: "You're all set.",
                            body: "Thank you for choosing PasaHERO");

                        _confettiController.stop();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        "Start Exploring",
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ).then((_) => _confettiController.dispose());
  }

  void _showTutorial() {
    final targets = [
      TargetFocus(
        keyTarget: logoIconKey,
        identify: "LogoIcon",
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "About & Suggestions",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Tap here to view app information, feedback, and suggestions for improvements.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      TargetFocus(
        keyTarget: searchToggleKey,
        identify: "SearchToggle",
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Route Search",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Use this button to search for available routes and destinations.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      TargetFocus(
        keyTarget: trafficToggleKey,
        identify: "TrafficToggle",
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Live Traffic",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Enable or disable live traffic updates to get real-time traffic information along your route.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      TargetFocus(
        keyTarget: locationButtonKey,
        identify: "LocationButton",
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Current Location",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  "Tap here to show your current location on the map and start your journey.",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ];

    TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        print("Tutorial finished");
        _showWelcomeModal();
      },
      onSkip: () {
        print("Tutorial skipped");
        _showWelcomeModal();
        return true;
      },
      skipWidget: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            ' ',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    ).show(context: context);
  }
}
