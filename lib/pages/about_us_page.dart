import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../pages/terms_and_conditions_page.dart';

class AboutUsPage extends StatefulWidget {
  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  final TextEditingController _messageController = TextEditingController();
  bool showModal = false;

  // Get the user email dynamically here
  String? userEmail = FirebaseAuth.instance.currentUser?.email;

  void _sendEmail(String message) async {
    if (userEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User email not found!')),
      );
      return;
    }

    final smtpServer = gmail(
      dotenv.env['EMAIL_ADDRESS']!,
      dotenv.env['EMAIL_PASSWORD']!,
    );

    final emailMessage = Message()
      ..from = Address(userEmail!, 'PasaHERO Inquiry') // user sends the email
      ..recipients.add('pasahero2025@gmail.com') // your fixed recipient email
      ..subject = 'PasaHERO Suggestion / Request'
      ..text = message;

    try {
      await send(emailMessage, smtpServer);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message sent successfully!'),
          backgroundColor: Colors.amber,
        ),
      );
      _messageController.clear();
      FocusScope.of(context).unfocus(); // Dismiss the keyboard
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send email.')),
      );
    }
  }

  void _showTermsModal() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text('Terms & Conditions',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          height: 700,
          child: TermsAndConditionsPage(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: Color.fromRGBO(26, 163, 94, 1),
        title: Text('About Us'),
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
            color: Colors.white, fontSize: 25, fontWeight: FontWeight.bold),
        toolbarHeight: 50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(5)),
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                height: 10,
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 10),
                  Text(
                    'Who we are?',
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      color: Colors.green[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 30),
                  Text(
                    '''We provide routing platform, and location-based alarm application for Muntinlupa City. We aim to help commuters to be notified to their loading & unloading points, to avoid missing their stops or getting lost.''',
                    style: TextStyle(fontSize: 17),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '''It was proudly created by students from Pamantasan ng Lungsod ng Muntinlupa, aiming to make commuting easier and smarter for a commuter like you.''',
                    style: TextStyle(fontSize: 17),
                  ),
                ],
              ),

              SizedBox(height: 30),

              /*Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'Developers\n\n'
                  '1. Aromin, Dexter R.\n'
                  '2. Damayo, Patrick Ian B.\n'
                  '3. Labro, Sean Vennedict A.',
                  style: TextStyle(fontSize: 15, color: Colors.grey[700]),
                ),
              ),
              SizedBox(height: 50),*/
              Text(
                'Contact Us',
                style: GoogleFonts.poppins(
                    fontSize: 26,
                    color: Colors.green[600],
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 30),

              /// 📨 Suggestion Box
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "If you've encountered a problem or have a suggestion, please free to send a message",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: _messageController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Write your message...",
                  filled: true,
                  fillColor: Color(0xFFF2F2F2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    if (_messageController.text.trim().isNotEmpty) {
                      _sendEmail(_messageController.text.trim());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 29, 181, 15),
                      padding: EdgeInsets.symmetric(vertical: 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      )),
                  child: Text(
                    'Send',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text.rich(
                  TextSpan(
                    text: "By using this app, you agree to our ",
                    style: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.grey.shade600),
                    children: [
                      TextSpan(
                        text: "Terms and Conditions",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color(0xFF04BE62),
                          fontWeight: FontWeight.w500,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = _showTermsModal,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(
                height: 50,
              ),

              Center(
                child: Column(
                  children: [
                    Center(
                        child: Image.asset('lib/assets/small_logo.png',
                            width: 30)),
                    const SizedBox(height: 10),
                    Text(
                      'All rights reserved © 2025',
                      style: TextStyle(
                        color: Color.fromARGB(255, 110, 110, 110),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Project by SPaDe | Designed and Developed by A.D.R",
                      style: TextStyle(
                        fontSize: 12,
                        color: Color.fromARGB(255, 201, 201, 201),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
