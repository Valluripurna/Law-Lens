import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<dynamic> _favorites = [];

  final String _baseUrl = "https://law-lens-backend-9yhz.onrender.com";

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');
    if (userId == null) return;

    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/favorites?userId=$userId'));
      if (response.statusCode == 200) {
        setState(() {
          _favorites = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching favorites: $e");
    }
  }

  Future<void> _removeFavorite(int index) async {
    final item = _favorites[index];
    final String favoriteId = item['id'];

    setState(() {
      _favorites.removeAt(index);
    });

    try {
      await http.delete(Uri.parse('$_baseUrl/api/favorites/$favoriteId'));
      Fluttertoast.showToast(msg: "Removed from favorites", backgroundColor: Colors.redAccent);
    } catch (e) {
      debugPrint("Error deleting favorite: $e");
      Fluttertoast.showToast(msg: "Could not remove favorite", backgroundColor: Colors.orange);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite_border, size: 64, color: Colors.redAccent),
            ),
            const SizedBox(height: 24),
            const Text(
              "Your Legal Vault is Empty",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E2A38)),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 50),
              child: Text(
                "Save important legal breakdowns here for quick reference anytime.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey, height: 1.5),
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
        final String answer = item['answer'] ?? "No response available.";
        final String question = item['question'] ?? "Legal Inquiry";
        final String formattedDate = item['timestamp'] != null && item['timestamp']['_seconds'] != null
            ? DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(item['timestamp']['_seconds'] * 1000))
            : "Recently Saved";

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 15,
                offset: const Offset(0, 5),
              )
            ],
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A38).withAlpha(10),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.gavel_rounded, color: Color(0xFF1E2A38), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E2A38)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.grey, size: 22),
                      onPressed: () => _removeFavorite(index),
                    )
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      answer,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                             showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
                                builder: (_) => DraggableScrollableSheet(
                                  initialChildSize: 0.7,
                                  maxChildSize: 0.9,
                                  minChildSize: 0.5,
                                  expand: false,
                                  builder: (context, scrollController) => SingleChildScrollView(
                                    controller: scrollController,
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Legal Breakdown", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                                          ],
                                        ),
                                        const Divider(height: 32),
                                        Text(answer, style: const TextStyle(fontSize: 16, height: 1.6)),
                                      ],
                                    ),
                                  ),
                                ),
                             );
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 18),
                          label: const Text("View Full Details", style: TextStyle(fontWeight: FontWeight.bold)),
                          style: TextButton.styleFrom(foregroundColor: const Color(0xFFD4AF37)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
