import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:async';
import '../services/notification_service.dart';

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
            // Fallback to central India if completely failed
            _currentPosition ??= const LatLng(20.5937, 78.9629); 
         });
      }
      Fluttertoast.showToast(msg: 'GPS signal weak. Using fallback location.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Zone Status", style: TextStyle(fontWeight: FontWeight.bold))),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFFD4AF37)),
              SizedBox(height: 16),
              Text('Acquiring GPS Signal...'),
            ],
          ),
        ),
      );
    }

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
      body: FlutterMap(
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
      floatingActionButton: _buildLegendCard(),
    );
  }

  Widget _buildLegendCard() {
    return Card(
      elevation: 6,
      color: Colors.white.withAlpha(240),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const Text("Zone Legend", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E2A38))),
             const SizedBox(height: 8),
             Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.local_police, color: Colors.redAccent, size: 16), SizedBox(width: 8), Text("Police Checkpost", style: TextStyle(fontSize: 12))]),
             const SizedBox(height: 4),
             Row(mainAxisSize: MainAxisSize.min, children: const [Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16), SizedBox(width: 8), Text("High Risk Area", style: TextStyle(fontSize: 12))]),
          ],
        ),
      ),
    );
  }
}
