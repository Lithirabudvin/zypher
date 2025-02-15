import 'package:flutter/material.dart';
import 'sign_up_screen.dart';
import 'compost_monitor_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void signIn() async {
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Check if the email is verified
      if (userCredential.user?.emailVerified ?? false) {
        // Navigate to the main screen after successful sign-in
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => CompostMonitorScreen()),
        );
      } else {
        // Prompt the user to verify their email
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Please verify your email before signing in."),
            action: SnackBarAction(
              label: "Resend Verification Email",
              onPressed: () => resendVerificationEmail(userCredential.user!),
            ),
          ),
        );
      }
    } catch (error) {
      // Handle sign-in errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign In Failed: ${error.toString()}")),
      );
    }
  }

  // Method to resend verification email
  void resendVerificationEmail(User user) async {
    try {
      await user.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text("Verification email sent. Please check your inbox.")),
      );
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                "Failed to resend verification email: ${error.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Sign In"),
        centerTitle: true,
        backgroundColor: Colors.lightBlue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: "Password"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: signIn,
              child: Text("Sign In"),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpScreen()),
                );
              },
              child: Text("Don't have an account? Sign Up"),
            ),
          ],
        ),
      ),
    );
  }
}
