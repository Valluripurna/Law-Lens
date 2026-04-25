import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalFeedScreen extends StatefulWidget {
  const LegalFeedScreen({super.key});

  @override
  State<LegalFeedScreen> createState() => _LegalFeedScreenState();
}

class _LegalFeedScreenState extends State<LegalFeedScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, String>> _newsItems = [];
  bool _isLoadingNews = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchNews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchNews() async {
    setState(() => _isLoadingNews = true);
    try {
      // Scraping LiveLaw (Top Stories)
      final response = await http.get(Uri.parse('https://www.livelaw.in/top-stories'));
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        var articles = document.querySelectorAll('.item-details');
        
        List<Map<String, String>> items = [];
        for (var i = 0; i < articles.length && i < 15; i++) {
          var titleElement = articles[i].querySelector('h3 a');
          var summaryElement = articles[i].querySelector('p');
          if (titleElement != null) {
            items.add({
              'title': titleElement.text.trim(),
              'url': 'https://www.livelaw.in${titleElement.attributes['href']}',
              'summary': summaryElement?.text.trim() ?? 'Tap to read more about this legal update.'
            });
          }
        }
        setState(() {
          _newsItems = items;
          _isLoadingNews = false;
        });
      }
    } catch (e) {
      debugPrint("Scraping error: $e");
      setState(() => _isLoadingNews = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Legal Intelligence", style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.newspaper), text: "Latest News"),
            Tab(icon: Icon(Icons.play_circle_fill), text: "Legal Reels"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNewsTab(),
          const LegalReelsTab(),
        ],
      ),
    );
  }

  Widget _buildNewsTab() {
    if (_isLoadingNews) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
    }
    return RefreshIndicator(
      onRefresh: _fetchNews,
      color: const Color(0xFFD4AF37),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _newsItems.length,
        itemBuilder: (context, index) {
          final item = _newsItems[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(item['summary']!, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
              trailing: const Icon(Icons.open_in_new, color: Color(0xFFD4AF37), size: 20),
              onTap: () async {
                 if (await canLaunchUrl(Uri.parse(item['url']!))) {
                   await launchUrl(Uri.parse(item['url']!), mode: LaunchMode.externalApplication);
                 }
              },
            ),
          );
        },
      ),
    );
  }
}

class LegalReelsTab extends StatefulWidget {
  const LegalReelsTab({super.key});

  @override
  State<LegalReelsTab> createState() => _LegalReelsTabState();
}

class _LegalReelsTabState extends State<LegalReelsTab> {
  // Public awareness / Sample legal content URLs
  final List<String> _videoUrls = [
    'https://assets.mixkit.co/videos/preview/mixkit-lawyer-preparing-the-case-for-the-court-23000-large.mp4',
    'https://assets.mixkit.co/videos/preview/mixkit-lawyer-having-a-meeting-with-a-client-in-the-office-23004-large.mp4',
    'https://assets.mixkit.co/videos/preview/mixkit-statue-of-lady-justice-in-a-legal-office-23001-large.mp4',
  ];

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      scrollDirection: Axis.vertical,
      itemCount: _videoUrls.length,
      itemBuilder: (context, index) {
        return ReelItem(url: _videoUrls[index], index: index);
      },
    );
  }
}

class ReelItem extends StatefulWidget {
  final String url;
  final int index;
  const ReelItem({super.key, required this.url, required this.index});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await _videoPlayerController.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: true,
      showControls: false,
      aspectRatio: _videoPlayerController.value.aspectRatio,
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_chewieController == null || !_chewieController!.videoPlayerController.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)));
    }
    return Stack(
      children: [
        Positioned.fill(
          child: Chewie(controller: _chewieController!),
        ),
        // Overlay Info
        Positioned(
          bottom: 40,
          left: 20,
          right: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("@LawLensAwareness", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text("Legal Awareness Series #${widget.index + 1}: Understanding your rights in court.", style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
        // Side Buttons
        Positioned(
          bottom: 100,
          right: 20,
          child: Column(
            children: [
              _buildSideIcon(Icons.favorite, "1.2k"),
              const SizedBox(height: 20),
              _buildSideIcon(Icons.comment, "85"),
              const SizedBox(height: 20),
              _buildSideIcon(Icons.share, "Share"),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildSideIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
