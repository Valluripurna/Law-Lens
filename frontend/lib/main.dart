import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await GoogleSignIn.instance.initialize();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const LawLensApp(),
    ),
  );
}

class LawLensApp extends StatelessWidget {
  const LawLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Navy Blue: #1E2A38, Gold: #D4AF37 defined as deep colors
    const Color primaryNavy = Color(0xFF1E2A38);
    const Color accentGold = Color(0xFFD4AF37);

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Law Lens',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryNavy, 
          secondary: accentGold,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryNavy,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryNavy,
            foregroundColor: accentGold,
          ),
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryNavy, 
          secondary: accentGold,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryNavy,
          foregroundColor: accentGold,
        ),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthWrapper()));
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                          ),
                          child: ClipOval(
                            child: Image.asset('assets/logo.png', width: 140, height: 140, fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Law Lens',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E2A38),
                            letterSpacing: 2.0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'AI Legal Assistant',
                          style: TextStyle(fontSize: 16, color: Color(0xFF1E2A38)),
                        )
                      ],
                    ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _onboardingSeen = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
    
    User? firebaseUser = FirebaseAuth.instance.currentUser;
    bool isLoggedIn = false;

    if (firebaseUser != null && firebaseUser.email != null) {
      try {
        // 1. Force token refresh to check Firebase Auth state
        await firebaseUser.getIdToken(true);
        
        // 2. STRENGTHENED AUTH: Check Firestore database directly
        // This ensures that if Admin deletes user from Firestore, the app kicks them out.
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.email)
            .get();

        if (userDoc.exists) {
          isLoggedIn = true;
        } else {
          // Account deleted from database by Admin
          await FirebaseAuth.instance.signOut();
          isLoggedIn = false;
        }
      } catch (e) {
        // If network error, allow local session for offline sync, 
        // but if e.code is user-not-found, log out.
        if (e.toString().contains('user-not-found')) {
          await FirebaseAuth.instance.signOut();
          isLoggedIn = false;
        } else {
          isLoggedIn = true; // Assume logged in for intermittent network issues
        }
      }
    }

    if (mounted) {
      setState(() {
        _onboardingSeen = onboardingSeen;
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (!_onboardingSeen) {
      return const OnboardingScreen();
    }
    
    return _isLoggedIn ? const HomeScreen() : const LoginScreen();
  }
}
