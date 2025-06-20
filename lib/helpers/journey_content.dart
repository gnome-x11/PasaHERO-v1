//helpers/journey_content.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:transit/helpers/jpurney_step.dart';
import 'package:transit/models/route_cards.dart';
import '../models/journey_plan.dart';

class JourneyContent extends StatelessWidget {
  final AsyncSnapshot<JourneyPlan?> snapshot;
  final TextEditingController routeNameController;
  final VoidCallback onSaveRoute;
  final TextEditingController startLocationController;
  final TextEditingController destinationController;
  final Future<Map<String, dynamic>> Function(JourneyPlan) buildStepByStepGuide;


  const JourneyContent({
    super.key,
    required this.snapshot,
    required this.routeNameController,
    required this.onSaveRoute,
    required this.startLocationController,
    required this.destinationController,
    required this.buildStepByStepGuide,
  });

  @override
  Widget build(BuildContext context) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!snapshot.hasData || snapshot.data == null) {
      return const Center(child: Text("Could not calculate route"));
    }

    final journeyPlan = snapshot.data!;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildDragHandle(),
            _buildRouteSaveForm(context),
            _buildRouteInfoCard(journeyPlan),
            _buildRouteGuideInstructions(journeyPlan),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 20),
        width: 50,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.grey[400],
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildRouteSaveForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: TextField(
        controller: routeNameController,
        decoration: InputDecoration(
          labelText: 'Enter route name',
          hintText: '* This field is required',
          labelStyle: GoogleFonts.poppins(
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
          hintStyle: GoogleFonts.poppins(
            color: Colors.redAccent.withOpacity(0.6),
            fontSize: 13,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: const Color.fromARGB(255, 241, 241, 241),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          suffixIcon: _buildSaveButton(context),
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Container(
        margin: const EdgeInsets.only(right: 5),
        decoration: const BoxDecoration(
          color: Color(0xFF04BE62),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.check, color: Colors.white),
          onPressed: onSaveRoute,
        ),
      ),
    );
  }

  Widget _buildRouteInfoCard(JourneyPlan journeyPlan) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Route Information",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
                Icons.location_on, "Start:", startLocationController.text,
                iconColor: Colors.blue),
            _buildInfoRow(
                Icons.flag, "Destination:", destinationController.text,
                iconColor: Colors.red),
            const SizedBox(height: 5),
            Column(
              children: [
                Text(
                    "Routes to ride:\n\n${journeyPlan.vehicleSegments.map((e) => e.route.displayName).join('→')}",
                  style: GoogleFonts.poppins(fontSize: 14),
                ),
              ],
            ),
            const SizedBox(
              height: 10,
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildRouteGuideInstructions(JourneyPlan journeyPlan) {
  return Padding(
    padding: const EdgeInsets.all(5.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        Text(
          "Step By Step Guide",
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<Map<String, dynamic>>(
          future: buildStepByStepGuide(journeyPlan),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (!snapshot.hasData) {
              return const Center(child: Text("No steps available"));
            }

            // Retrieve both journeySteps and cards from the result
            final journeySteps = snapshot.data!['journeySteps'] as List<JourneyStep>;
            final cards = snapshot.data!['steps'] as List<Widget>;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JourneySummary(journeySteps: journeySteps),
                const SizedBox(height: 10),
                ...cards,
              ],
            );
          },
        ),
      ],
    ),
  );
}


  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: iconColor ?? Colors.black),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black,
                ),
                children: [
                  TextSpan(
                    text: label,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: " $value"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}