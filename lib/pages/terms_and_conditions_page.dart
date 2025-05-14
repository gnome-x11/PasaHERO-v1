import 'package:flutter/material.dart';

class TermsAndConditionsPage extends StatelessWidget {
  const TermsAndConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Welcome to PASAHERO – your smart commuting companion in Muntinlupa City!\n\n'
            'By using the PASAHERO mobile application (“App”), you agree to the following Terms and Conditions. '
            'Please read them carefully.\n\n'
            '1. Acceptance of Terms\n'
            'By accessing or using the App, you agree to be bound by these Terms. If you do not agree, please do not use the App.\n\n'
            '2. Description of Service\n'
            'PASAHERO is a commuting route guide that helps users navigate Muntinlupa City using jeepneys and walking paths. It provides:\n'
            '- Step-by-step commuting instructions\n'
            '- Jeepney route recommendations\n'
            '- Walking directions to and from loading/unloading points\n'
            '- Transfer information when needed\n\n'
            '3. User Responsibilities\n'
            '- You agree to use PASAHERO for lawful purposes only.\n'
            '- You are responsible for your own safety while commuting.\n'
            '- Always double-check routes and surroundings while traveling.\n\n'
            '4. Data and Location Usage\n'
            '- The App collects your location to provide accurate routing and nearby jeepney terminals.\n'
            '- Location data may be stored to improve future suggestions and allow route saving.\n'
            '- We do not share your personal information with third parties without consent.\n\n'
            '5. Limitations and Disclaimers\n'
            '- Routes are based on available jeepney paths and may not reflect real-time traffic or changes.\n'
            '- PASAHERO is not liable for any delays, route changes, or incidents during your commute.\n'
            '- We do not guarantee 100% accuracy of routing information at all times.\n\n'
            '6. Updates and Modifications\n'
            'We may update these Terms and the App’s features from time to time. Continued use of the App after changes implies acceptance of the new Terms.\n\n'
            '7. Contact Us\n'
            'Have questions or feedback? Reach out at the suggestion field below.\n\n'
            'By using PASAHERO, you agree to abide by these Terms. Stay safe and enjoy your commute!',
            style: TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }
}
