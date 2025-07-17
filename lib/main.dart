import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/host_screen.dart';
import 'components/buttons/primary_button.dart';
import 'components/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'screens/pin_security_screen.dart';
import 'package:flutter/services.dart';
//import 'package:flutter/rendering.dart'; // activate only to see boundaries

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();
  //debugPaintSizeEnabled = true; // Add this line to see all widget boundaries

  // Lock orientation to portrait mode only (normal portrait)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp();

  runApp(const MafiaModeratorApp());
}

class MafiaModeratorApp extends StatelessWidget {
  const MafiaModeratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mafia Moderator',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkGray,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // SVG Icon
            SvgPicture.asset(
              'assets/logos/main_screen_logo.svg',
              width: 120,
              height: 120,
              colorFilter: ColorFilter.mode(
                AppColors.white,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 0),

            // MAFIA Title
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Column(
                children: [
                  Text(
                    'MAFIA',
                    style: TextStyle(
                      fontSize: 56,
                      fontFamily: 'AlfaSlabOne',
                      color: AppColors.white,
                      letterSpacing: 8.0,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 8,
                          color: Colors.black87,
                        ),
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 4,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'MOD TOOL',
                    style: TextStyle(
                      fontSize: 32,
                      fontFamily: 'AlfaSlabOne',
                      color: AppColors.white,
                      letterSpacing: 8.0,
                      shadows: [
                        Shadow(
                          offset: Offset(2, 2),
                          blurRadius: 8,
                          color: Colors.black87,
                        ),
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 4,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu Buttons
            PrimaryButton(
              text: 'HOST',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HostScreen()),
                );
              },
            ),
            const SizedBox(height: 50),

            PrimaryButton(
              text: 'GUIDE',
              onPressed: () {
                debugPrint('GUIDE button pressed');
              },
            ),
            const SizedBox(height: 50),

            PrimaryButton(
              text: 'DEV', // Change to SUPPORT in production
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PinSecurityScreen()),
                );
              },
            ),
            const SizedBox(height: 50),

            PrimaryButton(
              text: 'ABOUT',
              onPressed: () {
                debugPrint('ABOUT button pressed');
              },
            ),
          ],
        ),
      ),
    );
  }
}