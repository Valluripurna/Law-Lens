import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _carouselController = ScrollController();
  final List<Message> _messages = [];
  
  bool _isLoading = false;
  bool _vanishMode = false;
  String? _userId;
  String _language = "English";
  String? _attachedImagePath;
  Timer? _carouselTimer;
  final List<String> _quickQueries = [
    "Helmet fine?",
    "Overspeeding penalty?",
    "What is IPC 420?",
    "Punishment for murder?",
    "Bail procedure?",
    "Drunk driving laws?",
    "Police arrest rights"
  ];

  // BACKEND URL - Updated for Render
  static const String _baseUrl = "https://law-lens-backend-det5.onrender.com";

  @override
  void initState() {
    super.initState();
    _loadUserAndHistory();
    _startCarousel();
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_carouselController.hasClients) {
        double maxScroll = _carouselController.position.maxScrollExtent;
        double currentScroll = _carouselController.offset;
        double target = currentScroll + 150;
        if (target > maxScroll) target = 0;
        _carouselController.animateTo(
          target,
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userUid');
      _language = prefs.getString('language') ?? "English";
    });
    if (_userId != null) {
      await _fetchHistory();
    }
  }

  Future<void> _fetchHistory() async {
    if (_userId == null) return;
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/history?userId=$_userId'))
          .timeout(const Duration(seconds: 40));
      if (response.statusCode == 200) {
        final List<dynamic> historyData = json.decode(response.body);
        setState(() {
          _messages.clear();
          for (var item in historyData.reversed) {
            _messages.add(Message(text: item['question'], isUser: true));
            _messages.add(Message(text: item['answer'], isUser: false));
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching history: $e");
    }
  }

  // CALLING BACKEND API
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty && _attachedImagePath == null) return;
    String promptText = text.trim();
    _messageController.clear();
    
    String uiText = promptText;
    if (_attachedImagePath != null) {
      uiText = "📸 [Image Attached] $uiText";
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentLanguage = prefs.getString('language') ?? "English";

    setState(() {
      _language = currentLanguage;
      _messages.add(Message(text: uiText, isUser: true));
      _isLoading = true;
    });

    try {
      String responseText;
      
      if (_attachedImagePath != null) {
        // IMAGE UPLOAD
        var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/upload-image'));
        request.fields['userId'] = _userId ?? '';
        request.fields['question'] = promptText;
        request.fields['language'] = _language;
        request.fields['useVanishMode'] = _vanishMode.toString();
        request.files.add(await http.MultipartFile.fromPath('image', _attachedImagePath!));

        var streamedResponse = await request.send().timeout(const Duration(seconds: 45));
        var response = await http.Response.fromStream(streamedResponse);
        var jsonRes = json.decode(response.body);
        responseText = jsonRes['answer'] ?? "Could not analyze image.";
        _attachedImagePath = null;

      } else {
        // TEXT CHAT
        final response = await http.post(
          Uri.parse('$_baseUrl/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': _userId,
            'question': promptText,
            'language': _language,
            'useVanishMode': _vanishMode,
          }),
        ).timeout(const Duration(seconds: 45));
        
        final jsonRes = json.decode(response.body);
        responseText = jsonRes['answer'] ?? "The Law Lens server is momentarily silent. Please try again.";
      }

      setState(() {
        _messages.add(Message(text: responseText, isUser: false));
        _isLoading = false;
      });

    } catch (e) {
      String errMsg = "Connection to Law Lens server timed out or failed. Please check your internet or Render backend status. Error: $e";
      _showError(errMsg);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    
    setState(() {
       _attachedImagePath = image.path;
    });
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blueAccent),
                title: const Text('Upload Image (Challan/Accident)'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                title: const Text('Upload PDF (Legal Notice/FIR)'),
                onTap: () {
                  Navigator.pop(context);
                  Fluttertoast.showToast(msg: 'PDF processing is coming in Phase 3!', backgroundColor: const Color(0xFF1E2A38), textColor: const Color(0xFFD4AF37));
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addToFavorites(int index) async {
    String response = _messages[index].text;
    String question = index > 0 && _messages[index-1].isUser ? _messages[index-1].text : "Saved Response";
    
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> favs = prefs.getStringList('favorites') ?? [];
    favs.add(json.encode({
      'question': question, 
      'answer': response, 
      'timestamp': DateTime.now().toIso8601String()
    }));
    await prefs.setStringList('favorites', favs);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Added to Favorites! 💖"),
        backgroundColor: Colors.green,
      ));
    }
  }

  void _showError(String err) {
    setState(() {
      _messages.add(Message(text: err, isUser: false, isError: true));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_vanishMode)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.red.shade900.withAlpha(200), Colors.black.withAlpha(220)]),
              border: const Border(bottom: BorderSide(color: Colors.redAccent, width: 0.5))
            ),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 14, color: Colors.white),
                SizedBox(width: 8),
                Text("Vanish Mode: Secure & Private Session Active", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(25), blurRadius: 4, offset: const Offset(0, 2))]
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   const Text("Law Lens AI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E2A38))),
                   Row(
                     children: [
                       Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                       const SizedBox(width: 6),
                       const Text("Stable Connection", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.w500)),
                     ],
                   )
                 ],
               ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _vanishMode = !_vanishMode;
                    _messages.clear();
                    if (!_vanishMode) {
                      _fetchHistory();
                    }
                  });
                  Fluttertoast.showToast(
                    msg: _vanishMode ? "Vanish Mode ON - Data not saved" : "Vanish Mode OFF - Syncing history",
                    gravity: ToastGravity.TOP,
                    backgroundColor: _vanishMode ? Colors.redAccent : const Color(0xFF1E2A38),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _vanishMode ? Colors.redAccent : Colors.grey.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _vanishMode ? Colors.red : Colors.grey.shade300)
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _vanishMode ? Icons.visibility_off_outlined : Icons.shield_outlined, 
                        size: 18, 
                        color: _vanishMode ? Colors.white : Colors.grey.shade600
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Vanish", 
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold,
                          color: _vanishMode ? Colors.white : Colors.grey.shade700
                        )
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return Align(
                alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: msg.isError 
                        ? Colors.red.withAlpha(51) 
                        : (msg.isUser ? Theme.of(context).primaryColor : Colors.grey.withAlpha(51)),
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: msg.isUser ? const Radius.circular(0) : const Radius.circular(16),
                      bottomLeft: msg.isUser ? const Radius.circular(16) : const Radius.circular(0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text,
                        style: TextStyle(color: msg.isUser ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color),
                      ),
                      if (!msg.isUser && !msg.isError)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.share, size: 20, color: Colors.blueAccent),
                                onPressed: () => SharePlus.instance.share(ShareParams(text: msg.text)),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.only(right: 16),
                              ),
                              IconButton(
                                icon: const Icon(Icons.favorite_border, size: 20, color: Colors.redAccent),
                                onPressed: () => _addToFavorites(index),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
          ),
        SizedBox(
          height: 50,
          child: ListView.builder(
            controller: _carouselController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _quickQueries.length * 100,
            itemBuilder: (context, index) {
              final q = _quickQueries[index % _quickQueries.length];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 12)),
                  backgroundColor: const Color(0xFF1E2A38).withAlpha(25),
                  side: BorderSide.none,
                  onPressed: () => _sendMessage(q),
                ),
              );
            },
          ),
        ),
        if (_attachedImagePath != null)
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             margin: const EdgeInsets.symmetric(horizontal: 16),
             decoration: BoxDecoration(
               color: Colors.grey.shade200,
               borderRadius: BorderRadius.circular(8)
             ),
             child: Row(
               children: [
                 const Icon(Icons.image, color: Colors.green),
                 const SizedBox(width: 8),
                 const Expanded(child: Text("Image Attached Ready", style: TextStyle(color: Colors.black87))),
                 IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _attachedImagePath = null)),
               ],
             ),
           ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle, color: Color(0xFF1E2A38), size: 28),
                onPressed: _showAttachmentOptions,
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Ask your question here...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onSubmitted: _sendMessage,
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: const Color(0xFF1E2A38),
                child: IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFFD4AF37)),
                  onPressed: () => _sendMessage(_messageController.text),
                ),
              )
            ],
          ),
        )
      ],
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  final bool isError;
  Message({required this.text, required this.isUser, this.isError = false});
}
