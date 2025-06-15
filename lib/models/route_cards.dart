// utils

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/utils/journey_planner.dart';

double calculateWalkDistance(List<LatLng> path) {
  double distance = 0;
  for (int i = 1; i < path.length; i++) {
    distance += calculateDistance(path[i - 1], path[i]);
  }
  return distance;
}

class WalkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double distance;

  const WalkCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 243, 225),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.orange.shade100,
            child: const Icon(Icons.directions_walk, color: Colors.orange),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                ),
                Text(
                  "${distance.toStringAsFixed(0)} meters",
                  style: GoogleFonts.poppins(fontSize: 13, color: Colors.black),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

//return jepp step by step

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
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.directions_bus, color: Colors.blue),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                routeName,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.arrow_circle_down, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(boarding,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.arrow_circle_up, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(
                child: Text(alighting,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
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
      color: const Color.fromARGB(255, 247, 255, 232),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.green.withOpacity(0.2),
              radius: 30,
              child: const Icon(
                Icons.flag,
                color: Colors.green,
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Arrive at Destination",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    destination,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
