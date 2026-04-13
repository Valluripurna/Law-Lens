import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;
  String? _userId;
  final String _baseUrl = "https://law-lens-backend-det5.onrender.com";

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userUid');
    
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/history?userId=$_userId'));
      if (response.statusCode == 200) {
        setState(() {
          _history = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("History Load Error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text("No history found.", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: Text(
              item['question'],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              item['timestamp'] != null 
                ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(item['timestamp']['_seconds'] != null ? DateTime.fromMillisecondsSinceEpoch(item['timestamp']['_seconds'] * 1000).toIso8601String() : DateTime.now().toIso8601String()))
                : "Recent",
              style: const TextStyle(fontSize: 12),
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
