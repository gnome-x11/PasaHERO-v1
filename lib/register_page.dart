import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:transit/login_page.dart';
import 'package:transit/pages/home_page.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:transit/pages/terms_and_conditions_page.dart';

class RegisterAccountPage extends StatefulWidget {
  @override
  _RegisterAccountPageState createState() => _RegisterAccountPageState();
}

class _RegisterAccountPageState extends State<RegisterAccountPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  final bool _isLoading = false;

  // Function to register user
  void _register() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPassword = _confirmPasswordController.text.trim();
    String firstName = _firstNameController.text.trim();
    String lastName = _lastNameController.text.trim();

    // Input validation
    if (email.isEmpty ||
        password.isEmpty ||
        firstName.isEmpty ||
        lastName.isEmpty) {
      _showSnackBar("Please fill in all fields");
      return;
    }

    final emailRegex =
        RegExp(r"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$");
    if (!emailRegex.hasMatch(email)) {
      _showSnackBar("Please enter a valid email");
      return;
    }

    RegExp uppercase = RegExp(r'[A-Z]');
    RegExp specialCharacter = RegExp(r'[!@#$%^&*(),.?":{}|<>]');
    RegExp number = RegExp(r'[0-9]');
    if (password.length < 8) {
      _showSnackBar("Password must be at least 6 characters long");
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar("Passwords do not match");
      return;
    }

    if (!uppercase.hasMatch(password)) {
      _showSnackBar("Password must contain at least one uppercase letter");
      return;
    }
    if (!specialCharacter.hasMatch(password)) {
      _showSnackBar("Password must contain at least one special character");
      return;
    }
    if (!number.hasMatch(password)) {
      _showSnackBar("Password must contain at least one number");
      return;
    }

    try {
      // Register user in Firebase Authentication
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      String userId = userCredential.user?.uid ?? '';

      // Save user details in Firestore (without storing password!)
      await FirebaseFirestore.instance.collection('user').doc(userId).set({
        'user_fname': firstName,
        'user_lname': lastName,
        'user_email': email,
      });

      _showSnackBar("Account created successfully");

      // Navigate to Login Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginRegisterPage()),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage;

      if (e.code == 'email-already-in-use') {
        errorMessage = "This email is already registered.";
      } else if (e.code == 'weak-password') {
        errorMessage = "Password should be at least 8 characters.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Invalid email format.";
      } else {
        errorMessage = "Registration failed: ${e.message}";
      }

      _showSnackBar(errorMessage);
    } catch (e) {
      print("Error: $e");
      _showSnackBar("An error occurred. Please try again.");
    }
  }

  // Helper function to show snack bars
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
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

  Future<void> _registerWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut(); // Ensures the user selects an account

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        return; // User canceled the sign-in
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);

      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          await FirebaseFirestore.instance
              .collection('user')
              .doc(user.uid)
              .set({
            'user_fname': user.displayName?.split(" ").first ?? "",
            'user_lname': user.displayName?.split(" ").last ?? "",
            'user_email': user.email,
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Signed in successfully"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage(title: '')),
        );
      }
    } catch (e) {
      print("Google Sign-In Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to sign in with Google"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          // Navigate back to login page when back button is pressed
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginRegisterPage()),
          );
          return false; // Prevent default back behavior
        },
        child: Scaffold(
            body: GestureDetector(
          onHorizontalDragEnd: (details) {
            // Detect swipe to right (back gesture)
            if (details.primaryVelocity! > 0) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginRegisterPage()),
              );
            }
          },
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(height: 80),
                // Logo
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Image.asset(
                    'lib/assets/small_logo.png',
                    width: 80,
                  ),
                ),

                SizedBox(height: 20),
                Align(
                  alignment: Alignment.center,
                  child: Center(
                    child: Text(
                      "Welcome to PasaHERO!",
                      style: GoogleFonts.poppins(
                        fontSize: 25,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 35.0, vertical: 20.0),
                    child: Text(
                      "Let's create your account",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: Color.fromARGB(255, 41, 41, 41),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 15),

                // Personal Information Section
                _buildSectionHeader("Personal Information"),
                SizedBox(height: 10),

                // First Name Input Field
                _buildTextField(
                  _firstNameController,
                  "First Name",
                  "Enter your first name",
                  icon: Icons.person_outline,
                ),
                SizedBox(height: 15),

                // Last Name Input Field
                _buildTextField(
                  _lastNameController,
                  "Last Name",
                  "Enter your last name",
                  icon: Icons.person_outline,
                ),
                SizedBox(height: 20),

                // Account Information Section
                _buildSectionHeader("Account Information"),
                SizedBox(height: 10),

                // Email Input Field
                _buildTextField(
                  _emailController,
                  "Email",
                  "Enter your email",
                  icon: Icons.email_outlined,
                ),
                SizedBox(height: 15),

                // Password Input Field
                _buildPasswordField(
                  controller: _passwordController,
                  label: "Password",
                  hint: "Enter your password",
                  icon: Icons.lock_outline,
                  isVisible: _isPasswordVisible,
                  onVisibilityChanged: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
                ),
                SizedBox(height: 15),

                // Confirm Password Input Field
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: "Confirm Password",
                  hint: "Confirm your password",
                  icon: Icons.lock_outline,
                  isVisible: _isConfirmPasswordVisible,
                  onVisibilityChanged: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
                SizedBox(height: 40),

                // Sign Up Button
                ElevatedButton(
                  onPressed: _register,
                  style: ElevatedButton.styleFrom(
                    padding:
                        EdgeInsets.symmetric(horizontal: 142, vertical: 15),
                    backgroundColor: Color(0xFF04BE62),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Sign Up",
                    style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),

                // OR separator
                SizedBox(height: 20),
                _buildOrDivider(),
                SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: _isLoading ? null : _registerWithGoogle,
                  icon: Image.asset(
                    'lib/assets/google-color.png',
                    width: 20,
                    height: 20,
                  ),
                  label: Text(
                    "Continue with Google",
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 73, vertical: 15),
                    backgroundColor: Color(0xFF),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: Colors.grey,
                          width: 1.2,
                        )),
                  ),
                ),

                if (_isLoading)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFF04BE62)),
                      ),
                    ),
                  ),

                // Google Sign-In Button

                SizedBox(height: 40),
                // Already have an account Text
                _buildLoginPrompt(),
                SizedBox(height: 50),

                // Terms and Conditions Text
                _buildTermsAndConditionsText(),
                SizedBox(height: 50),
              ],
            ),
          ),
        )));
  }

  Widget _buildSectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 8.0),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color.fromARGB(255, 98, 98, 98),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, String hint,
      {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey),
            hintText: hint,
            prefixIcon:
                icon != null ? Icon(icon, size: 20, color: Colors.grey) : null,
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                  color: const Color.fromARGB(255, 181, 181, 181), width: 1.2),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(
                  color: const Color.fromARGB(255, 181, 181, 181), width: 1.2),
              borderRadius: BorderRadius.circular(10),
            ),
          )),
    );
  }

  Widget _buildPasswordField(
      {required TextEditingController controller,
      required String label,
      required String hint,
      required bool isVisible,
      required VoidCallback onVisibilityChanged,
      IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30.0),
      child: TextField(
        controller: controller,
        obscureText: !isVisible,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey),
          hintText: hint,
          prefixIcon:
              icon != null ? Icon(icon, size: 20, color: Colors.grey) : null,
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: const Color.fromARGB(255, 181, 181, 181), width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
                color: const Color.fromARGB(255, 181, 181, 181), width: 1.2),
            borderRadius: BorderRadius.circular(10),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              isVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 19,
              color: Colors.grey,
            ),
            onPressed: onVisibilityChanged,
          ),
        ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                thickness: 1,
                color: Colors.grey,
                indent: 30,
                endIndent: 0,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(10),
              child: Text(
                "OR",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            Expanded(
              child: Divider(
                thickness: 1,
                color: Colors.grey,
                indent: 0,
                endIndent: 30,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Already have an account? ",
            style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                transitionDuration: Duration(milliseconds: 210),
                pageBuilder: (context, animation, secondaryAnimation) =>
                    LoginRegisterPage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
              ),
            );
          },
          child: Text("Sign in here", style: TextStyle(color: Colors.green)),
        ),
      ],
    );
  }

  Widget _buildTermsAndConditionsText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              "By continuing, you agree to the ",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
          GestureDetector(
            onTap: _showTermsModal,
            child: Text(
              "Terms and Conditions",
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Color(0xFF04BE62),
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
        ],
      ),
    );
  }
}
