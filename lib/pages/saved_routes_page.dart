import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:transit/pages/home_page.dart';

class SavedRoutesPage extends StatefulWidget {
  const SavedRoutesPage({super.key});

  @override
  State<SavedRoutesPage> createState() => _SavedRoutesPageState();
}

class _SavedRoutesPageState extends State<SavedRoutesPage> {
  late Stream<QuerySnapshot> _routesStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _routesStream = FirebaseFirestore.instance
        .collection('saved_routes')
        .where('userId', isEqualTo: user?.uid)
        .snapshots();
  }

  LatLng _mapPoint(Map<String, dynamic> data) {
    return LatLng(data['lat'], data['lng']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 26, 163, 94),
        title: Text(
          'Saved Routes',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
          ),
        ),
        iconTheme: IconThemeData(
          color: Colors.white, 
        ),
        toolbarHeight: 50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(5)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _routesStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return _buildNoDataCard();
          if (snapshot.data!.docs.isEmpty) return _buildNoDataCard();

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final route =
                  snapshot.data!.docs[index].data() as Map<String, dynamic>;
              return _buildRouteCard(
                  context, route, snapshot.data!.docs[index].id);
            },
          );
        },
      ),
    );
  }

  // No Data Yet Card
  Widget _buildNoDataCard() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          "No Data Yet",
          style: GoogleFonts.poppins(
              fontSize: 18, fontWeight: FontWeight.normal, color: Colors.grey),
        ),
      ),
    );
  }

  // Route Card with Google Maps Preview
  Widget _buildRouteCard(
      BuildContext context, Map<String, dynamic> route, String id) {
    final start = _mapPoint(route['start']);
    final end = _mapPoint(route['end']);
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: BorderSide(color: Colors.grey)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Google Map Preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(15),
              bottom: Radius.circular(5),
            ),
            child: SizedBox(
              height: 200,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: start,
                  zoom: 14,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('start'),
                    position: start,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueRed),
                  ),
                  Marker(
                    markerId: const MarkerId('end'),
                    position: end,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen),
                  ),
                },
                zoomControlsEnabled: true,
                scrollGesturesEnabled: false,
                tiltGesturesEnabled: false,
                rotateGesturesEnabled: false,
              ),
            ),
          ),
          // Route Details
          // Route Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text("Route: ${route['routeName']}",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _confirmDeleteRoute(id),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text("Saved Date: ${route['savedDate']}",
                    style: const TextStyle(fontSize: 14, color: Colors.grey)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _useSavedRoute(context, route),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF04BE62),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text("Use Route",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// Add these new methods
  void _confirmDeleteRoute(String documentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Delete Route"),
          content: const Text("Are you sure you want to delete this route?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                _deleteRoute(documentId);
                Navigator.pop(context);
              },
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteRoute(String documentId) async {
    try {
      await FirebaseFirestore.instance
          .collection('saved_routes')
          .doc(documentId)
          .delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Route deleted successfully")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to delete route")),
      );
    }
  }

  void _useSavedRoute(BuildContext context, Map<String, dynamic> route) {
    final start = _mapPoint(route['start']);
    final end = _mapPoint(route['end']);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => HomePage(
                title: 'Home Page',
                initialStart: start,
                initialEnd: end,
              )),
    );
  }
}
