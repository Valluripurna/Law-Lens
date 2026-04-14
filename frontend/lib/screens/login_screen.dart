import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLogin = true;
  bool _isAgreed = false;

  Future<void> _submitNormal() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (!_isLogin && name.isEmpty)) {
      Fluttertoast.showToast(msg: 'Please fill all fields', backgroundColor: const Color(0xFFF9C15A), textColor: Colors.black);
      return;
    }

    if (!_isLogin && !_isAgreed) {
      Fluttertoast.showToast(msg: 'Please agree to the Terms and Conditions', backgroundColor: Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authServiceInstance = AuthService();
      Map<String, dynamic> result;
      if (_isLogin) {
        result = await authServiceInstance.login(email, password);
      } else {
        result = await authServiceInstance.signup(email, password);
      }

      if (!mounted) return;
      if (result['success']) {
        if (!_isLogin) {
          Fluttertoast.showToast(msg: 'Account created! Please Sign In.', backgroundColor: Colors.green);
          setState(() {
            _isLogin = true;
          });
        } else {
          Fluttertoast.showToast(msg: 'Welcome back!', backgroundColor: const Color(0xFFFAC25A), textColor: Colors.black);
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      } else {
        Fluttertoast.showToast(msg: result['error'] ?? 'Authentication failed', backgroundColor: Colors.redAccent);
      }
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: 'Error: $e', backgroundColor: Colors.redAccent);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authServiceInstance = AuthService();
      final result = await authServiceInstance.signInWithGoogle();
      
      if (!mounted) return;
      if (result['success']) {
        final String email = result['email'];
        final String uid = result['uid'];
        final String? photoUrl = result['photoUrl'];
        
        bool exists = await authServiceInstance.userExists(email);

        if (!mounted) return;

        if (_isLogin) {
          // LOGIN MODE
          if (exists) {
            await authServiceInstance.logout(); // Clear any temp session
            // Now log in properly (re-authenticating isn't needed here for check, but we need to save session)
            // The result already has the credential. We just need to save.
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('jwt_token', uid);
            await prefs.setString('userId', uid);
            await prefs.setString('userEmail', email);
            if (photoUrl != null) {
              await prefs.setString('userPhotoUrl', photoUrl);
            }

            if (!mounted) return;
            Fluttertoast.showToast(msg: 'Welcome back!', backgroundColor: const Color(0xFFFAC25A), textColor: Colors.black);
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
          } else {
            // NOT REGISTERED in Firestore
            await authServiceInstance.logout(); // Wipe Firebase Auth session
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.clear(); // Wipe SharedPreferences
            if (!mounted) return;
            Fluttertoast.showToast(
              msg: 'Signup Required: No Law Lens account found for this Google ID.', 
              backgroundColor: Colors.blueGrey, 
              textColor: Colors.white,
              gravity: ToastGravity.CENTER
            );
            setState(() => _isLogin = false); // Guide them to Signup tab
          }
        } else {
          // SIGNUP MODE
          if (exists) {
            Fluttertoast.showToast(msg: 'Account already exists. Please Sign In.', backgroundColor: Colors.blueGrey);
            setState(() => _isLogin = true);
          } else {
            await authServiceInstance.registerUserInFirestore(email, uid, photoUrl: photoUrl);
            await authServiceInstance.logout(); // Force them to sign in
            Fluttertoast.showToast(msg: 'Account created! Please Sign In now.', backgroundColor: Colors.green);
            setState(() => _isLogin = true);
          }
        }
      } else {
        String errMsg = result['error'] ?? 'Google Sign-In failed.';
        Fluttertoast.showToast(msg: errMsg, backgroundColor: Colors.blueGrey, textColor: Colors.white);
      }
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(msg: "Sign-in error: $e", backgroundColor: Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBg = Colors.white;
    const Color accentGold = Color(0xFFD4AF37);
    const Color navyText = Color(0xFF1E2A38);
    const Color fieldBg = Color(0xFFF0F2F5);

    return Scaffold(
      backgroundColor: darkBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Logo
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: navyText.withAlpha(12),
                      shape: BoxShape.circle,
                      border: Border.all(color: accentGold, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/logo.png', width: 80, height: 80, fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isLogin ? 'Law Lens' : 'Create Account',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: navyText, letterSpacing: 1.2),
                ),
                Text(
                  _isLogin ? 'Sign in to your AI Legal Assistant' : 'Join Law Lens — India\'s AI Legal Assistant',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.blueGrey),
                ),
                const SizedBox(height: 40),

                // Form Fields
                if (!_isLogin) ...[
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full name',
                    icon: Icons.person_outline,
                    fieldBg: fieldBg,
                  ),
                  const SizedBox(height: 16),
                ],

                _buildTextField(
                  controller: _emailController,
                  label: 'Email address',
                  icon: Icons.email_outlined,
                  fieldBg: fieldBg,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline,
                  fieldBg: fieldBg,
                  isPassword: true,
                ),
                
                if (_isLogin)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {},
                      child: const Text('Forgot password?', style: TextStyle(color: accentGold, fontSize: 13)),
                    ),
                  )
                else
                  const SizedBox(height: 16),

                if (!_isLogin) 
                  Row(
                    children: [
                      Checkbox(
                        value: _isAgreed,
                        onChanged: (v) => setState(() => _isAgreed = v ?? false),
                        activeColor: accentGold,
                        checkColor: Colors.black,
                        side: BorderSide(color: Colors.grey.shade700),
                      ),
                      const Expanded(
                        child: Text(
                          "I agree to the Terms of Service and Privacy Policy",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Primary Button
                _isLoading
                    ? const Center(child: CircularProgressIndicator(color: accentGold))
                    : MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: _submitNormal,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: accentGold,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: accentGold.withAlpha(80),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _isLogin ? 'Sign In' : 'Create Account',
                              style: const TextStyle(color: navyText, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                
                const SizedBox(height: 16),
                
                // Switch Mode
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_isLogin ? "Don't have an account? " : "Already have an account? ", style: const TextStyle(color: Colors.blueGrey, fontSize: 14)),
                    GestureDetector(
                      onTap: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin ? "Sign up" : "Sign in", 
                        style: const TextStyle(color: accentGold, fontWeight: FontWeight.bold, fontSize: 14)
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),
                const Row(
                  children: [
                    Expanded(child: Divider(color: Colors.black12)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("or", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: Colors.black12)),
                  ],
                ),
                const SizedBox(height: 32),

                // Google Button
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata, size: 28, color: navyText),
                  label: const Text('Continue with Google', style: TextStyle(color: navyText, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.black12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: fieldBg,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color fieldBg,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Color(0xFF1E2A38)),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.blueGrey, size: 20),
          hintText: label,
          hintStyle: const TextStyle(color: Colors.blueGrey, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }
}
