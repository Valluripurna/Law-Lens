import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import '../utils/pdf_generator.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen> {
  List<dynamic> _history = [];
  bool _isLoading = true;
  String? _userId;
  final String _baseUrl = "https://law-lens-backend-9yhz.onrender.com";

  @override
  void initState() {
    super.initState();
    loadHistory();
  }

  Future<void> loadHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');
    
    if (_userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    // 1. Instant Load from Cache
    String? cachedHistory = prefs.getString('history_cache_$_userId');
    if (cachedHistory != null) {
      setState(() {
        _history = json.decode(cachedHistory);
        _isLoading = false;
      });
    }

    // 2. Fetch from Server
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/history?userId=$_userId')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        // Update cache
        await prefs.setString('history_cache_$_userId', response.body);
        
        if (mounted) {
          setState(() {
            _history = json.decode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (_history.isEmpty) {
           Fluttertoast.showToast(msg: "History unavailable (${response.statusCode})");
        }
      }
    } catch (e) {
      debugPrint("History Load Error: $e");
      if (_history.isEmpty) {
        Fluttertoast.showToast(msg: "Offline: Could not sync history.");
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeHistory(int index) async {
    final item = _history[index];
    final String historyId = item['id'];

    setState(() {
      _history.removeAt(index);
    });

    try {
      await http.delete(Uri.parse('$_baseUrl/api/history/$historyId?userId=$_userId'));
      Fluttertoast.showToast(msg: "History record deleted", backgroundColor: Colors.redAccent);
    } catch (e) {
      debugPrint("Error deleting history: $e");
      Fluttertoast.showToast(msg: "Delete failed", backgroundColor: Colors.orange);
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
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.grey),
              onPressed: () => _removeHistory(index),
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
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                           String formattedDate = item['timestamp'] != null 
                              ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(item['timestamp']['_seconds'] != null ? DateTime.fromMillisecondsSinceEpoch(item['timestamp']['_seconds'] * 1000).toIso8601String() : DateTime.now().toIso8601String()))
                              : "Recent";
                           PdfGenerator.generateAndSharePDF(item['question'], item['answer'], formattedDate);
                        },
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                        label: const Text("Download PDF"),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                      ),
                    ),
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
