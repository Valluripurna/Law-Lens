import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _carouselController = ScrollController();
  final ScrollController _chatScrollController = ScrollController();
  final FlutterTts _flutterTts = FlutterTts();
  final List<Message> _messages = [];
  List<Message> _normalChatCache = [];
  final Set<int> _favoritedIndices = {};
  
  int? _playingIndex;
  bool _isPlaying = false;
  
  bool _isLoading = false;
  bool _vanishMode = false;
  String? _userId;
  String _language = "English";
  String? _attachedImagePath;
  String? _attachedPdfText;
  String? _attachedPdfName;
  Timer? _carouselTimer;
  final List<String> _quickQueries = [
    "Helmet fine?",
    "Overspeeding penalty?",
    "What is IPC 420?",
    "Punishment for murder?",
    "Bail procedure?",
    "Drunk driving laws?",
    "Police arrest rights",
    "Section 144 meaning",
    "Cyber crime report",
    "Divorce laws india",
    "RTI application",
    "Consumer court help",
    "Tenant rights",
    "Property registration",
    "Legal aid for poor",
    "Dowry laws",
    "POCSO act basics"
  ];

  // BACKEND URL - Updated for Render
  static const String _baseUrl = "https://law-lens-backend-9yhz.onrender.com";

  @override
  void initState() {
    super.initState();
    _loadUserAndHistory();
    _startCarousel();
    
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _playingIndex = null;
          _isPlaying = false;
        });
      }
    });
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
    _chatScrollController.dispose();
    _messageController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScrollController.hasClients) {
        _chatScrollController.animateTo(
          _chatScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _speak(int index, String text) async {
    if (_playingIndex == index) {
      if (_isPlaying) {
        await _flutterTts.pause();
        setState(() => _isPlaying = false);
      } else {
        await _flutterTts.speak(text);
        setState(() => _isPlaying = true);
      }
    } else {
      await _flutterTts.stop();
      await _flutterTts.setLanguage("en-IN");
      await _flutterTts.setPitch(1.0);
      setState(() {
        _playingIndex = index;
        _isPlaying = true;
      });
      await _flutterTts.speak(text);
    }
  }

  Future<void> _loadUserAndHistory() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _userId = prefs.getString('userId');
      _language = prefs.getString('language') ?? "English";
    });
    if (_userId != null) {
      await _fetchHistory();
      await _fetchFavorites();
    }
  }

  Future<void> _fetchFavorites() async {
    if (_userId == null) return;
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/favorites?userId=$_userId'))
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final List<dynamic> favData = json.decode(response.body);
        final Set<String> favAnswers = favData.map((e) => e['answer'].toString()).toSet();
        
        setState(() {
          _favoritedIndices.clear();
          for (int i = 0; i < _messages.length; i++) {
            if (!_messages[i].isUser && favAnswers.contains(_messages[i].text)) {
              _favoritedIndices.add(i);
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching favorites for sync: $e");
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
    if (text.trim().isEmpty && _attachedImagePath == null && _attachedPdfText == null) return;
    String promptText = text.trim();
    _messageController.clear();
    
    String uiText = promptText;
    if (_attachedImagePath != null) {
      uiText = "📸 [Image Attached] $uiText";
    } else if (_attachedPdfText != null) {
      uiText = "📄 [PDF: $_attachedPdfName] $uiText";
      promptText = "CONTEXT FROM PDF DOCUMENT:\n$_attachedPdfText\n\nUSER QUESTION: $promptText";
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String currentLanguage = prefs.getString('language') ?? "English";

    setState(() {
      _language = currentLanguage;
      _messages.add(Message(text: uiText, isUser: true));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      if (_attachedImagePath != null) {
        // IMAGE UPLOAD (No stream)
        var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/upload-image'));
        request.fields['userId'] = _userId ?? '';
        request.fields['question'] = promptText;
        request.fields['language'] = _language;
        request.fields['useVanishMode'] = _vanishMode.toString();
        request.files.add(await http.MultipartFile.fromPath('image', _attachedImagePath!));

        var sResponse = await request.send().timeout(const Duration(seconds: 45));
        var response = await http.Response.fromStream(sResponse);
        var jsonRes = json.decode(response.body);
        
        setState(() {
          _messages.add(Message(text: jsonRes['answer'] ?? "Could not analyze image.", isUser: false));
          _isLoading = false;
        });
        _scrollToBottom();
        _attachedImagePath = null;
        _attachedPdfText = null;
        _attachedPdfName = null;

      } else {
        // TEXT CHAT STREAMING
        final request = http.Request('POST', Uri.parse('$_baseUrl/api/chat'));
        request.headers['Content-Type'] = 'application/json';
        request.body = json.encode({
          'userId': _userId,
          'question': promptText,
          'language': _language,
          'useVanishMode': _vanishMode,
        });

        setState(() {
          _messages.add(Message(text: "...", isUser: false, isStreaming: true));
          _isLoading = false;
        });

        final sResponse = await request.send().timeout(const Duration(seconds: 45));
        bool firstChunk = true;
        
        await for (var chunk in sResponse.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          for (var line in lines) {
            if (line.startsWith('data: ')) {
               final dataStr = line.substring(6);
               if (dataStr.trim() == '[DONE]') {
                 setState(() {
                   _messages.last = Message(text: _messages.last.text, isUser: false, isStreaming: false);
                 });
                 break;
               }
               try {
                 final jsonData = json.decode(dataStr);
                 if (jsonData['chunk'] != null) {
                    setState(() {
                      var lastMsg = _messages.last;
                      if (firstChunk) {
                        _messages.last = Message(text: jsonData['chunk'], isUser: false, isStreaming: true);
                        firstChunk = false;
                      } else {
                        _messages.last = Message(text: lastMsg.text + jsonData['chunk'], isUser: false, isStreaming: true);
                      }
                    });
                    _scrollToBottom();
                 } else if (jsonData['error'] != null) {
                    _showError(jsonData['error']);
                 }
               } catch (e) {
                 // Ignore parsing errors for partial chunks
               }
            }
          }
        }
      }

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
       _attachedPdfText = null;
    });
  }

  Future<void> _pickPDF() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      final File file = File(result.files.single.path!);
      try {
        final PdfDocument document = PdfDocument(inputBytes: await file.readAsBytes());
        final String text = PdfTextExtractor(document).extractText();
        document.dispose();
        
        setState(() {
          _attachedPdfText = text.length > 5000 ? text.substring(0, 5000) : text;
          _attachedPdfName = result.files.single.name;
          _attachedImagePath = null;
        });
        Fluttertoast.showToast(msg: "PDF Picked & Parsed!");
      } catch (e) {
        _showError("Failed to parse PDF: $e");
      }
    }
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
                  _pickPDF();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleFavorite(int index) async {
    if (_userId == null || _userId!.isEmpty) {
      Fluttertoast.showToast(msg: "Please log in to save favorites.");
      return;
    }

    bool isCurrentlyFavorited = _favoritedIndices.contains(index);
    String responseText = _messages[index].text;

    // OPTIMISTIC UI: Instantly change the heart state
    setState(() {
      if (isCurrentlyFavorited) {
        _favoritedIndices.remove(index);
      } else {
        _favoritedIndices.add(index);
      }
    });

    if (isCurrentlyFavorited) {
      // API CALL TO UNFAVORITE
      try {
        final getResponse = await http.get(Uri.parse('$_baseUrl/api/favorites?userId=$_userId'));
        if (getResponse.statusCode == 200) {
          final List<dynamic> favs = json.decode(getResponse.body);
          final match = favs.firstWhere((f) => f['answer'] == responseText, orElse: () => null);
          
          if (match != null) {
            String favId = match['id'];
            final delResponse = await http.delete(Uri.parse('$_baseUrl/api/favorites/$favId?userId=$_userId'));
            if (delResponse.statusCode == 200) {
              Fluttertoast.showToast(msg: "Removed from Favorites 🤍");
              return;
            }
          }
        }
        // Rollback if not found or failed
        setState(() => _favoritedIndices.add(index));
      } catch (e) {
        setState(() => _favoritedIndices.add(index));
        debugPrint("Unfavorite Error: $e");
      }
    } else {
      // API CALL TO FAVORITE
      String question = index > 0 && _messages[index-1].isUser ? _messages[index-1].text : "Saved Response";
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/api/favorites'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': _userId,
            'question': question,
            'answer': responseText,
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          Fluttertoast.showToast(msg: "Added to Favorites 💖");
        } else {
          setState(() => _favoritedIndices.remove(index));
        }
      } catch (e) {
        setState(() => _favoritedIndices.remove(index));
        Fluttertoast.showToast(msg: "Failed to save to cloud.");
      }
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
                    if (_vanishMode) {
                      // Entering Vanish Mode: Cache current chat
                      _normalChatCache = List.from(_messages);
                      _messages.clear();
                      _favoritedIndices.clear();
                    } else {
                      // Exiting Vanish Mode: Restore from cache or fetch latest history
                      _messages.clear();
                      if (_normalChatCache.isNotEmpty) {
                        _messages.addAll(_normalChatCache);
                        _normalChatCache.clear();
                      } else {
                        _fetchHistory();
                      }
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
            controller: _chatScrollController,
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
                      msg.isUser
                        ? Text(
                            msg.text,
                            style: TextStyle(color: Colors.white),
                          )
                        : MarkdownBody(
                            data: msg.text + (msg.isStreaming ? " █" : ""),
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.5, fontSize: 15),
                              strong: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.bold),
                              a: const TextStyle(color: Colors.blueAccent, decoration: TextDecoration.underline),
                            ),
                            onTapLink: (text, href, title) async {
                              if (href != null) {
                                final uri = Uri.parse(href);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                } else {
                                  Fluttertoast.showToast(msg: "Could not launch URL");
                                }
                              }
                            },
                          ),
                      if (!msg.isUser && !msg.isError)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.copy, size: 20, color: Colors.blueGrey),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: msg.text));
                                  Fluttertoast.showToast(msg: "Copied to clipboard!");
                                },
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.only(right: 16),
                              ),
                              IconButton(
                                icon: const Icon(Icons.share, size: 20, color: Colors.blueAccent),
                                onPressed: () => SharePlus.instance.share(ShareParams(text: msg.text)),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.only(right: 16),
                              ),
                              IconButton(
                                  icon: Icon(
                                    _favoritedIndices.contains(index) ? Icons.favorite : Icons.favorite_border, 
                                    size: 20, 
                                    color: Colors.redAccent
                                  ),
                                  onPressed: () => _toggleFavorite(index),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.only(right: 16),
                              ),
                              IconButton(
                                icon: Icon(
                                  _playingIndex == index && _isPlaying ? Icons.pause_circle_filled : Icons.volume_up, 
                                  size: 22, 
                                  color: _playingIndex == index && _isPlaying ? Colors.redAccent : Colors.green
                                ),
                                onPressed: () => _speak(index, msg.text),
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
              final colors = [
                Colors.blue.shade100,
                Colors.orange.shade100,
                Colors.green.shade100,
                Colors.purple.shade100,
                Colors.pink.shade100,
              ];
              final Color chipColor = colors[index % colors.length];

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  backgroundColor: chipColor,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
           if (_attachedPdfText != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.redAccent.withAlpha(50))
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(child: Text("Attached: $_attachedPdfName", style: const TextStyle(color: Colors.black87, fontSize: 13, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() {
                    _attachedPdfText = null;
                    _attachedPdfName = null;
                  })),
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
  final bool isStreaming;
  Message({required this.text, required this.isUser, this.isError = false, this.isStreaming = false});
}
