import 'dart:ui';
import 'package:flutter/material.dart';
import 'chat_screen.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        return true;
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0F2027),
                    Color(0xFF203A43),
                    Color(0xFF2C5364),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    width: 350,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Text(
                            "Create your account",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildInputField("Email address"),
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => ChatScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: Colors.black,
                              minimumSize: Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Text("Sign up"),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Already have an account?", style: TextStyle(color: Colors.white70)),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // OR navigate to Login if needed
                                },
                                child: Text("Log in", style: TextStyle(color: Colors.cyanAccent)),
                              ),
                            ],
                          ),
                          Divider(height: 32, color: Colors.white30),
                          Text("OR", style: TextStyle(color: Colors.white54)),
                          const SizedBox(height: 16),
                          _buildSocialButton(Icons.g_mobiledata, "Continue with Google"),
                          const SizedBox(height: 12),
                          _buildSocialButton(Icons.window, "Continue with Microsoft Account"),
                          const SizedBox(height: 12),
                          _buildSocialButton(Icons.apple, "Continue with Apple"),
                          const SizedBox(height: 24),
                          Text.rich(
                            TextSpan(
                              text: "Terms of Use",
                              style: TextStyle(
                                color: Colors.white54,
                                decoration: TextDecoration.underline,
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: "   |   ",
                                  style: TextStyle(decoration: TextDecoration.none),
                                ),
                                TextSpan(
                                  text: "Privacy Policy",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, {bool obscure = false}) {
    return TextField(
      obscureText: obscure,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.lightBlueAccent),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.lightBlueAccent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: Colors.cyanAccent, width: 2),
        ),
      ),
    );
  }

  Widget _buildSocialButton(IconData icon, String text) {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: Icon(icon, size: 20, color: Colors.white),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        side: BorderSide(color: Colors.white30),
      ),
    );
  }
}
