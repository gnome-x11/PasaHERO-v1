import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

// alarms_constants.dart
class AlarmConstants {
  static const List<AlarmSound> availableAlarmSounds = [
    AlarmSound(name: "Default Alarm", assetPath: "alarms_sound/alarm_1.mp3"),
    AlarmSound(name: "Time Capsule", assetPath: "alarms_sound/alarm_2.mp3"),
    AlarmSound(name: "Time Travel", assetPath: "alarms_sound/alarm_3.mp3"),
    AlarmSound(name: "Morning Chime", assetPath: "alarms_sound/alarm_4.mp3"),
    AlarmSound(name: "Sea Breeze", assetPath: "alarms_sound/alarm_5.mp3"),
    AlarmSound(name: "Sugar Rush", assetPath: "alarms_sound/alarm_6.mp3"),
    AlarmSound(name: "Sunflower", assetPath: "alarms_sound/alarm_7.mp3"),
    AlarmSound(name: "Wake Me There", assetPath: "alarms_sound/alarm_8.mp3"),
  ];
}

class AlarmSound {
  final String name;
  final String assetPath;

  const AlarmSound({required this.name, required this.assetPath});
}

// Add to your alarms_constants.dart or create vibration_constants.dart
class VibrationConstants {
  static const List<VibrationPattern> availableVibrationPatterns = [
    VibrationPattern(name: "Default", pattern: [500]),
    VibrationPattern(name: "Short Pulse", pattern: [200, 200, 200]),
    VibrationPattern(
        name: "Heartbeat", pattern: [100, 100, 300, 300, 100, 100]),
    VibrationPattern(name: "Alert", pattern: [1000, 500, 1000]),
    VibrationPattern(name: "Notification", pattern: [300, 200, 300]),
  ];
}

class VibrationPattern {
  final String name;
  final List<int> pattern;

  const VibrationPattern({required this.name, required this.pattern});
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  User? user = FirebaseAuth.instance.currentUser;
  String username = "Loading...";
  String email = "Loading...";
  String profilePicUrl = "";
  AlarmSound selectedSound = AlarmConstants.availableAlarmSounds[0];
  bool isVibrationEnabled = true;
  VibrationPattern selectedVibration =
      VibrationConstants.availableVibrationPatterns[0];
  double alarmRadius = 100;
  bool isManualAccount = false;
  final AudioPlayer _audioPlayer = AudioPlayer(); // For sound preview

  final List<AlarmSound> alarmSounds = AlarmConstants.availableAlarmSounds;

  @override
  void initState() {
    super.initState();
    fetchUserDetails();
    _loadPreferences();
  }

  @override
  void dispose() {
    _audioPlayer.dispose(); // Clean up the audio player
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSoundName = prefs.getString('selectedSound') ?? "Default Alarm";
    final savedVibrationName =
        prefs.getString('selectedVibration') ?? "Default";

    setState(() {
      selectedSound = alarmSounds.firstWhere(
        (sound) => sound.name == savedSoundName,
        orElse: () => AlarmConstants.availableAlarmSounds[0],
      );
      selectedVibration =
          VibrationConstants.availableVibrationPatterns.firstWhere(
        (vib) => vib.name == savedVibrationName,
        orElse: () => VibrationConstants.availableVibrationPatterns[0],
      );
      isVibrationEnabled = prefs.getBool('isVibrationEnabled') ?? true;
      alarmRadius = prefs.getDouble('alarmRadius') ?? 100;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedSound', selectedSound.name);
    await prefs.setString('selectedVibration', selectedVibration.name);
    await prefs.setBool('isVibrationEnabled', isVibrationEnabled);
    await prefs.setDouble('alarmRadius', alarmRadius);
  }

  Future<void> fetchUserDetails() async {
    if (user != null) {
      setState(() {
        email = user!.email ?? "No Email";
        profilePicUrl = user!.photoURL ?? "";
      });

      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('user')
          .doc(user!.uid)
          .get();

      if (userDoc.exists) {
        setState(() {
          username = userDoc['user_fname'] ?? "No Name";
        });
      }

      List<UserInfo> providerData = user!.providerData;
      setState(() {
        isManualAccount =
            providerData.any((info) => info.providerId == "password");
      });
    }
  }

  Future<void> _showAlarmSoundPicker() async {
    await _audioPlayer.stop();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const SizedBox(height: 30),
                  Text("🎵 Choose Alarm Sound",
                      style: GoogleFonts.poppins(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: alarmSounds.length,
                      itemBuilder: (context, index) {
                        final sound = alarmSounds[index];
                        return Card(
                          color: const Color.fromARGB(255, 247, 224, 156),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 10),
                            title: Text(sound.name,
                                style: GoogleFonts.poppins(fontSize: 16)),
                            leading: IconButton(
                              icon: const Icon(Icons.play_arrow_rounded),
                              onPressed: () => _previewSound(sound),
                            ),
                            trailing: selectedSound.name == sound.name
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : null,
                            onTap: () {
                              setState(() => selectedSound = sound);
                              _savePreferences();
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) => _audioPlayer.stop());
  }

  Future<void> _showVibrationPatternPicker() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Select Vibration Pattern",
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  )),
              const SizedBox(height: 16),
              ...VibrationConstants.availableVibrationPatterns.map((pattern) {
                return ListTile(
                  leading: const Icon(Icons.vibration, color: Colors.orange),
                  title: Text(pattern.name, style: GoogleFonts.poppins()),
                  trailing: selectedVibration.name == pattern.name
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    setState(() {
                      selectedVibration = pattern;
                    });
                    _savePreferences();
                    _previewVibration(pattern);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Future<void> _previewSound(AlarmSound sound) async {
    try {
      await _audioPlayer.stop();
      // debugPrint("Playing from: ${sound.assetPath}");
      await _audioPlayer.play(AssetSource(sound.assetPath));
    } catch (e) {
      // debugPrint("Error playing sound: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not play the sound: ${e.toString()}")
        ),
      );
    }
  }

  Future<void> _previewVibration(VibrationPattern pattern) async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator != true) return;

    if (pattern.pattern.length == 1) {
      await Vibration.vibrate(duration: pattern.pattern[0]);
    } else {
      // For Android (with vibration pattern support)
      await Vibration.vibrate(pattern: pattern.pattern);
    }
  }

  void resetPassword() async {
    if (user != null && user!.email != null) {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user!.email!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Password reset email sent to ${user!.email}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Account Settings and Preferences'),
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.poppins(
            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        backgroundColor: Color.fromARGB(255, 26, 163, 94),
        toolbarHeight: 50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(5),
          ),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          const SizedBox(height: 130),
          CircleAvatar(
            radius: 50,
            backgroundImage: profilePicUrl.isNotEmpty
                ? NetworkImage(profilePicUrl) as ImageProvider
                : AssetImage('lib/assets/default_profile.jpg') as ImageProvider,
          ),
          SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: Text(
              "Sign in as: ",
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(height: 10),
          //
          Text(
            username,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            email,
            style: const TextStyle(
              fontSize: 16,
              color: Color.fromARGB(146, 10, 64, 5),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Customize alarm",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Personalize your alarm settings to match your preferences.",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 20),
            ]),
          ),
          // Update the Text widget that shows the selected sound:
          ListTile(
            title: const Text("Choose Alarm Sound"),
            subtitle: Text(selectedSound.name),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _showAlarmSoundPicker,
          ),

          const SizedBox(height: 10),
          Column(
            children: [
              SwitchListTile(
                title: const Text("Enable Vibration"),
                value: isVibrationEnabled,
                onChanged: (bool value) async {
                  setState(() {
                    isVibrationEnabled = value;
                  });
                  _savePreferences();

                  if (isVibrationEnabled) {
                    await _previewVibration(selectedVibration);
                  }
                },
                activeColor: const Color.fromARGB(255, 58, 160, 62),
              ),
              if (isVibrationEnabled) ...[
                ListTile(
                  title: const Text("Vibration Pattern"),
                  subtitle: Text(selectedVibration.name),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: _showVibrationPatternPicker,
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
          Divider(
            indent: 15,
            endIndent: 15,
            color: Colors.grey,
            thickness: 0.7,
          ),
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            child: Column(
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Drop-off Alarm Radius",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Adjust the radius to set how far from your destination the alarm should trigger.",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 30),
                Slider(
                  value: alarmRadius,
                  min: 50,
                  max: 200,
                  divisions: 3, // Changed from 2 to 8 for more granular control
                  label: "${alarmRadius.toInt()}m",
                  onChanged: (double value) {
                    setState(() {
                      alarmRadius = value;
                    });
                    _savePreferences();
                  },
                  activeColor: Colors.green,
                  thumbColor: Colors.green,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text("50 m"),
                    Text("100 m"),
                    Text("150 m"),
                    Text("200 m"),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 30,
          ),
          Divider(
            indent: 15,
            endIndent: 15,
            color: Colors.grey,
            thickness: 0.7,
          ),
          SizedBox(height: 50),
          if (isManualAccount) ...[
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Column(children: [
                  const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Change your Password",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ))
                ])),
            SizedBox(height: 20),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: Text(
                'NOTE: \n \nTo change your password, an email will be sent through your Google Account. \n'
                "Your password must have UPPERCASE('A, B, C'), NUMBER('1, 2, 3'), and SPECIAL CHARACTER ('@, #, %').",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ),
            SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: resetPassword,
                icon: Image.asset(
                  'lib/assets/email_logo.webp',
                  width: 20,
                  height: 20,
                ),
                label: Text(
                  "Send Change Password Email",
                  style: TextStyle(fontSize: 16, color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  side: BorderSide(color: Colors.black, width: 1.2),
                ),
              ),
            ),
            SizedBox(height: 20)
          ],
        ]),
      ),
    );
  }
}



