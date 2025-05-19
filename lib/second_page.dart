import 'package:blobs/blobs.dart';
import 'package:blobs/blobs.dart' as blob_package;
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:google_fonts/google_fonts.dart';

class SecondPage extends StatefulWidget {
  const SecondPage({super.key});

  @override
  State<SecondPage> createState() => _SecondPageState();
}

class _SecondPageState extends State<SecondPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // TOP LEFT BLOB
          Positioned(
            top: -100,
            left: -100,
            child: blob_package.Blob.animatedRandom(
              size: 500,
              styles: BlobStyles(color: Color.fromARGB(255, 214, 232, 212)),
              duration: Duration(seconds: 5),
              loop: true,
            ),
          ),

          // BOTTOM RIGHT BLOB
          Positioned(
            bottom: -90,
            right: -100,
            child: blob_package.Blob.animatedRandom(
              size: 350,
              styles: BlobStyles(color: Color.fromARGB(255, 214, 232, 212)),
              duration: Duration(seconds: 5),
              loop: true,
            ),
          ),

          SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 60),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    'Welcome To PasaHERO,',
                    style: GoogleFonts.poppins(
                      fontSize: 45,
                      fontWeight: FontWeight.w800,
                      color: Color.fromARGB(255, 4, 154, 79),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    'Discover real-time tracking, live updates, and route information, avoid missing a stop and avoid getting lost with our app!',
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color.fromARGB(255, 112, 112, 112)),
                    textAlign: TextAlign.start,
                  ),
                ),
                SizedBox(height: 50),

                /// **Animated Feature Slider**
                SizedBox(
                  height: 380,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    children: [
                      FeatureSlide(
                        imagePath: 'lib/assets/Automatic_route.png',
                        title: 'Automatic Routing Guide',
                        description:
                            'Effortlessly find the best jeepney routes to your destination with step-by-step guide.',
                        isActive: _currentPage == 0,
                      ),
                      FeatureSlide(
                        imagePath: 'lib/assets/location_alarm.png',
                        title: 'Location Based Alarm',
                        description:
                            "Get notified when it's time to get on or off your ride never miss your stop again.",
                        isActive: _currentPage == 1,
                      ),
                      FeatureSlide(
                        imagePath: 'lib/assets/real_time.png',
                        title: 'Real-Time Tracking',
                        description:
                            'Track your journey live and stay updated on your exact location throughout your commute.',
                        isActive: _currentPage == 2,
                      ),
                    ],
                  ),
                ),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return Container(
                      margin: EdgeInsets.symmetric(horizontal: 5),
                      width: _currentPage == index ? 12 : 8,
                      height: _currentPage == index ? 12 : 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Color(0xFF04BE62)
                            : Colors.grey,
                      ),
                    );
                  }),
                ),
                SizedBox(height: 45),

                /// **Continue Button**
                ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => LoginRegisterPage()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color.fromARGB(255, 2, 173, 88),
                    padding:
                        EdgeInsets.symmetric(horizontal: 130, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 100,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeatureSlide extends StatefulWidget {
  final String imagePath;
  final String title;
  final String description;
  final bool isActive;

  const FeatureSlide({
    super.key,
    required this.imagePath,
    required this.title,
    required this.description,
    required this.isActive,
  });

  @override
  State<FeatureSlide> createState() => _FeatureSlideState();
}

class _FeatureSlideState extends State<FeatureSlide>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    _animation = Tween<double>(begin: 0, end: -25).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _controller.reverse();
        } else if (status == AnimationStatus.dismissed && widget.isActive) {
          _controller.forward();
        }
      });

    if (widget.isActive) _controller.forward();
  }

  @override
  void didUpdateWidget(FeatureSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _controller.forward();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _animation.value),
                child: child,
              );
            },
            child: Image.asset(widget.imagePath,
                width: 200, height: 200, fit: BoxFit.cover),
          ),
          SizedBox(height: 20),
          Text(
            widget.title,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              widget.description,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
