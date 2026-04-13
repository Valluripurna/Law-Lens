import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<dynamic> _favorites = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> favStrings = prefs.getStringList('favorites') ?? [];
    setState(() {
      _favorites = favStrings.map((str) => json.decode(str)).toList().reversed.toList();
    });
  }

  Future<void> _removeFavorite(int index) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> favStrings = prefs.getStringList('favorites') ?? [];
    // The list is reversed for display, so we must find the original index
    int originalIndex = favStrings.length - 1 - index;
    favStrings.removeAt(originalIndex);
    await prefs.setStringList('favorites', favStrings);
    _loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite_border, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text(
              "No favorites saved yet.",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Click the heart icon on any AI response to save them here.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final item = _favorites[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: const Icon(Icons.favorite, color: Colors.redAccent),
            title: Text(
              item['question'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              item['timestamp'] != null 
                ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(item['timestamp']))
                : "Saved Response",
              style: const TextStyle(fontSize: 12),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => _removeFavorite(index),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("AI Response:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                    const SizedBox(height: 8),
                    Text(item['answer'] ?? "No response available."),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
