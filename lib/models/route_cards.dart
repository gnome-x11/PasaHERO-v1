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

// Sum of all segment durations in minutes
int calculateTotalDuration(List<JourneyStep> steps) {
  return steps.fold(0, (sum, step) => sum + step.duration);
}

// Sum of all segment distances in meters
double calculateTotalDistance(List<JourneyStep> steps) {
  return steps.fold(0.0, (sum, step) => sum + step.distance);
}

// Format time like "10:45 AM"
String formatTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

class JourneySummary extends StatelessWidget {
  final List<JourneyStep> journeySteps;

  const JourneySummary({super.key, required this.journeySteps});

  @override
  Widget build(BuildContext context) {
    final usedIcons = <String>{};

    final totalPrice =
        journeySteps.fold<double>(00, (sum, step) => sum + step.price);

    for (final step in journeySteps) {
      usedIcons.add(step.type);
    }

    // Calculate time and distance
    final totalMinutes = calculateTotalDuration(journeySteps);
    final totalDistanceMeters = calculateTotalDistance(journeySteps);
    final now = DateTime.now();
    final eta = now.add(Duration(minutes: totalMinutes));

    final formattedStart = formatTime(now);
    final formattedEta = formatTime(eta);
    final totalKm = (totalDistanceMeters / 1000).toStringAsFixed(2);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        const SizedBox(
          height: 10,
        ),
        Row(
          children: [
          Text(
            'Your Journey',
            style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            'Total fare: ${totalPrice.toStringAsFixed(0)} pesos',
            style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
            ),
          ),
          ],
        ),
        const SizedBox(height: 20,),
        Text('Route Summary:', style: GoogleFonts.poppins(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold),),
        const SizedBox(height: 20),
        Column(
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: journeySteps.map((step) {
            IconData icon;
            Color color;
            bool isDashed = false;
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
              isDashed = true;
            }

            return Expanded(
              child: GestureDetector(
              child: Column(
                children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 4),
                isDashed
                  ? Wrap(
                    spacing: 2,
                    children: List.generate(10, (_) {
                      return Container(
                      width: 2,
                      height: 3,
                      color: color,
                      );
                    }),
                    )
                  : Container(
                    height: 3,
                    margin: const EdgeInsets.only(right: 1),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    ),
                ],
              ),
              ),
            );
            }).toList(),
          ),

          // ⬇️ Time indicators row
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: journeySteps.map((step) {
            return Expanded(
              child: Center(
              child: Text(
                '${step.duration} min',
                style: GoogleFonts.poppins(
                  fontSize: 11, color: Colors.grey[700]),
              ),
              ),
            );
            }).toList(),
          ),

          const SizedBox(height: 10),
          Row(
            children: [
            Text(
              '|',
              style: TextStyle(
              fontSize: 18,
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Divider(
              thickness: 3,
              color: Colors.blue,
              ),
            ),
            Text(
              '|',
              style: TextStyle(
              fontSize: 18,
              color: Colors.blue,
              fontWeight: FontWeight.bold,
              ),
            ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
            Text(
              formattedStart,
              style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.green[700]),
            ),
            Text(
              '$totalKm km',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.orange),
            ),
            Text(
              'ETA: $formattedEta',
              style:
                GoogleFonts.poppins(fontSize: 12, color: Colors.red[700]),
            ),
            ],
          ),
          ],
        ),
        const SizedBox(
          height: 10,
        )
        ],
      ),
      ),
    );
  }
}

// ===================
// Modernized Cards
// ===================
class WalkCard extends StatelessWidget {
  final String direction;
  final double distance;
  final int duration;

  const WalkCard(
      {super.key,
      required this.direction,
      required this.distance,
      required this.duration});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color.fromARGB(255, 255, 236, 219),
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
                      Text("Walk",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const Spacer(),
                      const SizedBox(width: 16),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(direction,
                      style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: const Color.fromARGB(255, 43, 43, 43))),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    'Distance: ${distance.toStringAsFixed(0)} m',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(
                    height: 6,
                  ),
                  Text(
                    'Duration: ${duration.toString()} minutes',
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold),
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

class JeepCard extends StatelessWidget {
  final String routeName;
  final String boarding;
  final String alighting;
  final double distance;
  final int duration;

  const JeepCard({
    super.key,
    required this.routeName,
    required this.boarding,
    required this.alighting,
    required this.distance,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color.fromARGB(240, 215, 236, 249),
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
                      Text("Jeep",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const Spacer(),
                      Text(" Fare: 13 pesos",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildDetailRow("Route", routeName),
                  const SizedBox(height: 6),
                  _buildDetailRow("Get On", boarding),
                  const SizedBox(height: 6),
                  _buildDetailRow("Get Off", alighting),
                  const SizedBox(height: 6),
                  _buildDetailRow("Distance", "$km m"),
                  const SizedBox(height: 6),
                  _buildDetailRow("Duration", "${duration.toString()} minutes"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get km =>
      (distance / 1000).toStringAsFixed(2); // keeps 2 decimal places

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
                color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
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
  final double distance;
  final int duration;

  const TricycleCard({
    super.key,
    required this.routeName,
    required this.boarding,
    required this.alighting,
    required this.distance,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color.fromARGB(255, 244, 252, 245),
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
                      Text("Tricycle",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const Spacer(),
                      Text("Fare: 12 pesos",
                          style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.green)),
                      const SizedBox(width: 16),
                    ],
                  ),
                  const SizedBox(height: 30),
                  _buildDetailRow("Terminal", routeName),
                  const SizedBox(height: 6),
                  _buildDetailRow("Get On", boarding),
                  const SizedBox(height: 6),
                  _buildDetailRow("Get Off", alighting),
                  const SizedBox(height: 6),
                  _buildDetailRow("Distance", "$km km"),
                  const SizedBox(height: 6),
                  _buildDetailRow("Duration", "$duration minutes"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get km =>
      (distance / 1000).toStringAsFixed(2); // keeps 2 decimal places

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
                color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style:
                GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
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
      color: const Color.fromARGB(255, 227, 241, 228),
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
