// utils

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/helpers/jpurney_step.dart';
import 'package:transit/utils/journey_planner.dart';


double calculateWalkDistance(List<LatLng> path) {
  double distance = 0;
  for (int i = 1; i < path.length; i++) {
    distance += calculateDistance(path[i - 1], path[i]);
  }
  return distance;
}
class JourneySummary extends StatelessWidget {
  final List<JourneyStep> journeySteps;

  const JourneySummary({super.key, required this.journeySteps});

  @override
  Widget build(BuildContext context) {
    final totalPrice =
        journeySteps.fold<double>(0, (sum, step) => sum + step.price);

    final usedIcons = <String>{};
    for (final step in journeySteps) {
      usedIcons.add(step.type);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Calculated Route Plan:',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              'Total fare: ${totalPrice.toStringAsFixed(0)} pesos',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Icons above progress bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: journeySteps.map((step) {
            IconData icon;
            Color color;

            switch (step.type) {
              case 'jeep':
                icon = Icons.directions_bus;
                color = Colors.blue;
                break;
              case 'tricycle':
                icon = Icons.motorcycle;
                color = Colors.green;
                break;
              default:
                icon = Icons.directions_walk;
                color = Colors.orange;
            }

            return Expanded(
              child: Column(
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(height: 4),
                  Container(
                    height: 3,
                    margin: const EdgeInsets.only(right: 1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ===================
// Modernized Cards
// ===================
class WalkCard extends StatelessWidget {
  final String direction;
  final double distance;


  const WalkCard({
    super.key,
    required this.direction,
    required this.distance, 
    

  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.orange.shade50,
              radius: 24,
              child: Icon(Icons.directions_walk, color: Colors.orange),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("Walk", style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14
                      )),
                      const Spacer(),
                      const SizedBox(width: 16),
                      
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(direction, style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade700
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JeepCard extends StatelessWidget {
  final String routeName;
  final String boarding;
  final String alighting;


  const JeepCard({
    super.key,
    required this.routeName,
    required this.boarding,
    required this.alighting,

  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade50,
              radius: 24,
              child: Icon(Icons.directions_bus, color: Colors.blue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("Jeep", style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14
                      )),
                      const Spacer(),
                      Text(" Fare: 13 pesos", style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14
                      )),
                      const SizedBox(width: 16),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow("Route", routeName),
                  const SizedBox(height: 6),
                  _buildDetailRow("Get On", boarding),
                  const SizedBox(height: 6),
                  _buildDetailRow("Get Off", alighting),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            "$label:",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.grey.shade600
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class TricycleCard extends StatelessWidget {
  final String routeName;
  final String boarding;
  final String alighting;


  const TricycleCard({
    super.key,
    required this.routeName,
    required this.boarding,
    required this.alighting,

  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.shade50,
              radius: 24,
              child: Icon(Icons.motorcycle, color: Colors.green),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text("Tricycle", style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14
                      )),
                      const Spacer(),
                      Text("Fare: 12 pesos", style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14
                      )),
                      const SizedBox(width: 16),
                      
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildDetailRow("Terminal", routeName),
                  const SizedBox(height: 6),
                  _buildDetailRow("Get On", boarding),
                  const SizedBox(height: 6),
                  _buildDetailRow("Get Off", alighting),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            "$label:",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              fontSize: 13,
              color: Colors.grey.shade600
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class ArrivalCard extends StatelessWidget {
  final String destination;

  const ArrivalCard({
    super.key,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.shade50,
              radius: 24,
              child: Icon(Icons.flag, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Arrive at Destination",
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
