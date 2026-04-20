import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _receiveZoneAlerts = true;

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
      _receiveZoneAlerts = prefs.getBool('zoneAlerts') ?? true;
    });
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
          child: CircleAvatar(
            radius: 60,
            backgroundColor: Colors.blueAccent.withAlpha(51),
            backgroundImage: _photoUrl != null && _photoUrl!.isNotEmpty
              ? NetworkImage(_photoUrl!)
              : null,
            child: _photoUrl == null || _photoUrl!.isEmpty
                ? const Icon(Icons.person, size: 60, color: Colors.blueAccent)
                : null,
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
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.radar, color: Colors.blueAccent),
            title: const Text('Receive Zone Alerts'),
            subtitle: const Text('Notify me near checkposts & hotspots', style: TextStyle(fontSize: 12)),
            trailing: Switch(
              value: _receiveZoneAlerts,
              activeThumbColor: Colors.white,
              activeTrackColor: Colors.blueAccent,
              onChanged: (val) async {
                setState(() => _receiveZoneAlerts = val);
                SharedPreferences prefs = await SharedPreferences.getInstance();
                await prefs.setBool('zoneAlerts', val);
                Fluttertoast.showToast(msg: val ? "Zone Alerts ON" : "Zone Alerts OFF");
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
