import 'package:flutter/material.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';
import 'history_screen.dart';
import 'favorites_screen.dart';
import 'zone_status_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<FavoritesScreenState> _favoritesKey = GlobalKey();
  final GlobalKey<HistoryScreenState> _historyKey = GlobalKey();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const ChatScreen(),
      FavoritesScreen(key: _favoritesKey),
      const ZoneStatusScreen(),
      HistoryScreen(key: _historyKey),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(child: Image.asset('assets/logo.png', height: 28, width: 28, fit: BoxFit.cover)),
            const SizedBox(width: 12),
            const Text('Law Lens', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0)),
          ],
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) _favoritesKey.currentState?.loadFavorites();
          if (index == 3) _historyKey.currentState?.loadHistory();
        },
        type: BottomNavigationBarType.fixed, // Essential for 4+ items
        selectedItemColor: const Color(0xFFD4AF37),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Favorites'),
          BottomNavigationBarItem(icon: Icon(Icons.radar), label: 'Zone'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
