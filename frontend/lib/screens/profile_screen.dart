import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _email = "";
  String _language = "English";
  String? _photoUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _email = prefs.getString('userEmail') ?? "User";
      _language = prefs.getString('language') ?? "English";
      _photoUrl = prefs.getString('userPhotoUrl');
    });
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    
    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');
      if (userId == null) throw Exception("User ID not found");

      // 1. Reference & Task
      Reference ref = FirebaseStorage.instance.ref().child('profiles').child('$userId.jpg');
      
      // Monitor the upload task
      UploadTask uploadTask = ref.putFile(
        File(image.path),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Wait for completion with state monitoring
      await uploadTask.whenComplete(() => debugPrint("Upload Task Complete"));
      
      // 2. Get Download URL with a small retry-delay (helps if rules/storage are slow)
      await Future.delayed(const Duration(milliseconds: 800));
      String downloadUrl = await ref.getDownloadURL();

      // 3. Update Firestore & Local Storage
      await AuthService().updateProfilePicture(_email, downloadUrl);

      setState(() {
        _photoUrl = downloadUrl;
      });
      
      Fluttertoast.showToast(msg: "Profile picture updated! ✨");
    } catch (e) {
      String errMsg = e.toString();
      if (errMsg.contains('object-not-found')) {
        errMsg = "Storage Error: File was not found after upload. Check your Storage Rules.";
      } else if (errMsg.contains('unauthorized')) {
        errMsg = "Permission Denied: Ensure your Storage Rules allow access to 'profiles/'.";
      }
      Fluttertoast.showToast(msg: "Upload failed: $errMsg", backgroundColor: Colors.redAccent, textColor: Colors.white, gravity: ToastGravity.BOTTOM);
      debugPrint("Profile Upload Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _logout(BuildContext context) async {
    await AuthService().logout();
    if (!context.mounted) return;
    Fluttertoast.showToast(msg: "Logged out successfully", backgroundColor: const Color(0xFF1E2A38));
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.blueAccent.withAlpha(51),
                backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
                  ? NetworkImage(_photoUrl!)
                  : null,
                child: _photoUrl == null || _photoUrl!.isEmpty
                    ? const Icon(Icons.person, size: 60, color: Colors.blueAccent)
                    : null,
              ),
              if (_isUploading)
                const Positioned.fill(
                  child: Center(child: CircularProgressIndicator(color: Colors.white)),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _pickAndUploadImage,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _email,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        Card(
          child: ListTile(
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: isDark,
              onChanged: (val) {
                themeProvider.toggleTheme(val);
                Fluttertoast.showToast(
                  msg: val ? "Dark Mode ON" : "Light Mode ON",
                  backgroundColor: val ? Colors.black : Colors.white,
                  textColor: val ? Colors.white : Colors.black,
                  gravity: ToastGravity.SNACKBAR
                );
              },
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.language, color: Colors.blueAccent),
            title: const Text('Language'),
            trailing: DropdownButton<String>(
              value: _language,
              underline: const SizedBox(),
              items: <String>['English', 'Hindi', 'Telugu'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _language = val);
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.setString('language', val);
                  Fluttertoast.showToast(msg: "Language changed to $val");
                }
              },
            ),
          ),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => _logout(context),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        )
      ],
    );
  }
}
