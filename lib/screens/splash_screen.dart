import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'farmer_dashboard.dart';
import 'officer_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 3000), () async {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('user_role');
      
      if (mounted) {
        if (role == 'farmer') {
          final deviceId = prefs.getString('device_id');
          if (deviceId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => FarmerDashboard(deviceId: deviceId)),
            );
            return;
          }
        } else if (role == 'officer') {
          final officerId = prefs.getString('officer_id');
          if (officerId != null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => OfficerDashboard(officerId: officerId)),
            );
            return;
          }
        }
        
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // Exact solid background color from the uploaded screenshot
          color: Color(0xFF1E5A46),
        ),
        child: Stack(
          children: [
            // ── Decorative background circles matching the reference ──
            Positioned(
              top: -150,
              right: -100,
              child: Container(
                width: 450,
                height: 450,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF246651), // slightly lighter green for the circles
                ),
              ),
            ),
            Positioned(
              bottom: -250,
              left: -150,
              child: Container(
                width: 550,
                height: 550,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF246651),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.25,
              left: -100,
              child: Container(
                width: 250,
                height: 250,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF246651),
                ),
              ),
            ),

            // ── Main content ──
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with glowing background
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Glow effect
                      Container(
                        width: 240,
                        height: 240,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF34D399).withOpacity(0.12),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      // Transparent PNG Asset
                      Image.asset(
                        'assets/images/logo.png',
                        width: 220,
                        height: 220,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.eco_rounded,
                          size: 100,
                          color: Colors.white,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 1200.ms, curve: Curves.easeOut)
                          .scale(begin: const Offset(0.8, 0.8), end: const Offset(1.0, 1.0), duration: 1200.ms, curve: Curves.easeOut),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // App Name
                  Text(
                    "EcoWatch",
                    style: GoogleFonts.outfit(
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ).animate().fadeIn(delay: 400.ms, duration: 800.ms),

                  const SizedBox(height: 16),

                  // Tagline Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      "Smart Wildlife Monitoring",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ).animate().fadeIn(delay: 800.ms, duration: 800.ms),

                  const SizedBox(height: 60),

                  // Simple Arc Loader matching exactly the screenshot
                  SizedBox(
                    width: 32,
                    height: 32,
                    child: const CircularProgressIndicator(
                      color: Color(0xFF90CCA6), // soft muted green for the loader
                      strokeWidth: 2.5,
                    ),
                  ).animate().fadeIn(delay: 1200.ms, duration: 800.ms),
                ],
              ),
            ),

            // ── Bottom branding ──
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Text(
                "Intelligent Ecosystem Surveillance",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.35),
                  letterSpacing: 0.5,
                ),
              ).animate().fadeIn(delay: 1200.ms, duration: 800.ms),
            ),
          ],
        ),
      ),
    );
  }
}

