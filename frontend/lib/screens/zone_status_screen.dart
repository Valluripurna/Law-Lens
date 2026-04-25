import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import '../services/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ZoneStatusScreen extends StatefulWidget {
  const ZoneStatusScreen({super.key});

  @override
  State<ZoneStatusScreen> createState() => _ZoneStatusScreenState();
}

class _ZoneStatusScreenState extends State<ZoneStatusScreen> {
  LatLng? _currentPosition;
  bool _isLoading = true;
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _positionStream;
  LatLng? _lastAlertPosition;
  
  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  Future<void> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      Fluttertoast.showToast(msg: 'Location services are disabled.');
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        Fluttertoast.showToast(msg: 'Location permissions are denied');
        if (mounted) setState(() => _isLoading = false);
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      Fluttertoast.showToast(msg: 'Location permissions are permanently denied.');
      if (mounted) setState(() => _isLoading = false);
      return;
    } 

    try {
      // 1. Instantly try to get last known position for fast UI load
      Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _currentPosition = LatLng(lastKnown.latitude, lastKnown.longitude);
          _lastAlertPosition = _currentPosition;
          _isLoading = false;
        });
        _mapController.move(_currentPosition!, 14.0);
      }

      // 2. Try to get fresh highly accurate position with a timeout
      Position initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best)
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        if (lastKnown != null) return lastKnown;
        throw TimeoutException("GPS lock timed out.");
      });
      
      if (!mounted) return;
      setState(() {
        _currentPosition = LatLng(initialPosition.latitude, initialPosition.longitude);
        _lastAlertPosition = _currentPosition;
        _isLoading = false;
      });
      _mapController.move(_currentPosition!, 14.0);

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        if (!mounted) return;
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });

        if (_lastAlertPosition != null) {
          final double distance = const Distance().as(
            LengthUnit.Meter,
            _lastAlertPosition!,
            _currentPosition!,
          );
          
          if (distance >= 1000) { // 1km moved
            _lastAlertPosition = _currentPosition;
            NotificationService.showZoneAlert();
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _currentPosition ??= const LatLng(20.5937, 78.9629);
        });
      }
      Fluttertoast.showToast(msg: 'GPS signal weak. Using fallback location.');
    }
  }

  Future<void> _launchMaps(String query) async {
    final String url = "https://www.google.com/maps/search/?api=1&query=$query";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      Fluttertoast.showToast(msg: "Could not launch Google Maps");
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _currentPosition ?? const LatLng(20.5937, 78.9629); // Central India fallback

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
             Icon(Icons.radar, color: Colors.redAccent),
             SizedBox(width: 8),
             Text("Zone Status", style: TextStyle(fontWeight: FontWeight.bold)),
          ]
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              if (_currentPosition != null) {
                _mapController.move(_currentPosition!, 15.0);
              } else {
                _isLoading = true;
                setState(() {});
                _determinePosition();
              }
            },
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: _currentPosition != null ? 14.0 : 5.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.law_lens',
              ),
              MarkerLayer(
                markers: [
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 60.0,
                      height: 60.0,
                      child: const Column(
                        children: [
                          Icon(Icons.person_pin_circle, color: Colors.blueAccent, size: 40),
                          Text("You", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 12))
                        ],
                      ),
                    ),
                  if (_currentPosition != null)
                    Marker(
                      point: LatLng(_currentPosition!.latitude + 0.005, _currentPosition!.longitude + 0.005),
                      width: 80.0,
                      height: 80.0,
                      child: const Column(
                        children: [
                          Icon(Icons.local_police, color: Colors.redAccent, size: 30),
                          Text("Checkpost", style: TextStyle(fontWeight: FontWeight.bold, backgroundColor: Colors.white70, fontSize: 12))
                        ],
                      ),
                    ),
                  if (_currentPosition != null)
                    Marker(
                      point: LatLng(_currentPosition!.latitude - 0.004, _currentPosition!.longitude - 0.002),
                      width: 80.0,
                      height: 80.0,
                      child: const Column(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 30),
                          Text("High Risk", style: TextStyle(fontWeight: FontWeight.bold, backgroundColor: Colors.white70, fontSize: 12))
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            bottom: 100,
            right: 16,
            child: _buildLegendCard(),
          ),
          if (_isLoading)
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                      SizedBox(width: 8),
                      Text("Updating Location...", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ),
          _buildDraggableNearbySheet(),
        ],
      ),
    );
  }

  Widget _buildDraggableNearbySheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.15,
      minChildSize: 0.15,
      maxChildSize: 0.4,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 5)],
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const Text(
                "Nearby Legal Aid",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E2A38)),
              ),
              const SizedBox(height: 8),
              const Text("Find critical legal services near your location", style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildServiceButton("Police", Icons.local_police, Colors.blue),
                  _buildServiceButton("District Court", Icons.gavel, Colors.brown),
                  _buildServiceButton("High Court", Icons.account_balance, Colors.indigo),
                ],
              ),
              const SizedBox(height: 20),
              _buildServiceListItem("Search All Legal Aid", "Find lawyers, legal clinics, etc.", Icons.search, () => _launchMaps("Legal Aid Center near me")),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceButton(String label, IconData icon, Color color) {
    return Column(
      children: [
        InkWell(
          onTap: () => _launchMaps("$label near me"),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildServiceListItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
        child: Icon(icon, color: const Color(0xFF1E2A38), size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildLegendCard() {
    return Card(
      elevation: 4,
      color: Colors.white.withAlpha(240),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.local_police, color: Colors.redAccent, size: 14), SizedBox(width: 8), Text("Checkpost", style: TextStyle(fontSize: 10))]),
             const SizedBox(height: 4),
             Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14), SizedBox(width: 8), Text("Risk Area", style: TextStyle(fontSize: 10))]),
          ],
        ),
      ),
    );
  }
}
