import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpoofVacuum',
      theme: ThemeData(
        
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Spoofing GPS'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  // Mock service
  final _mockController = StreamController<Position>.broadcast();
  Timer? _mockTimer;
  bool _isMocking = false;

  // Toggle between mock stream and real device stream
  bool _useRealLocation = false;
  StreamSubscription<Position>? _realSub;
  StreamSubscription<Position>? _mockSub;

  // UI state
  double _lat = 16.85011;
  double _lng = 96.128573;
  Position? _currentPosition;

  // Geolocator stream settings (for real)
  final LocationSettings _locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
  );

  @override
  void dispose() {
    _stopMockingInternal();
    _realSub?.cancel();
    _mockSub?.cancel();
    _mockController.close();
    super.dispose();
  }

  // Start emitting mock positions every interval seconds
  void _startMocking({int intervalSeconds = 2}) {
    if (_isMocking) return;
    _isMocking = true;

    // Immediately emit one position
    _emitMockPosition();

    _mockTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      _emitMockPosition();
    });

    // If currently selected stream is mock, subscribe
    _subscribeToMockStream();
    setState(() {});
  }

  void _emitMockPosition() {
    final pos = Position(
      latitude: _lat,
      longitude: _lng,
      timestamp: DateTime.now(),
      accuracy: 1.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0, 
      altitudeAccuracy: 0.0, 
      headingAccuracy: 0.0,
    );
    _mockController.add(pos);
  }

  void _stopMocking() {
    _stopMockingInternal();
    _mockSub?.cancel();
    setState(() {});
  }

  void _stopMockingInternal() {
    _isMocking = false;
    _mockTimer?.cancel();
    _mockTimer = null;
  }

  // Subscribe to mock controller stream and update UI
  void _subscribeToMockStream() {
    _mockSub?.cancel();
    _mockSub = _mockController.stream.listen((pos) {
      setState(() {
        _currentPosition = pos;
      });
    });
  }

  // Subscribe to real device GPS stream (requires permissions)
  Future<void> _subscribeToRealLocation() async {
    // permission flow
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnack('Location permission denied');
        setState(() => _useRealLocation = false);
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showSnack('Location permission permanently denied. Open settings.');
      setState(() => _useRealLocation = false);
      return;
    }

    _realSub?.cancel();
    _realSub = Geolocator.getPositionStream(locationSettings: _locationSettings)
        .listen((pos) {
      setState(() {
        _currentPosition = pos;
      });
    }, onError: (e) {
      _showSnack('Error from location stream: $e');
    });
  }

  void _unsubscribeRealLocation() {
    _realSub?.cancel();
    _realSub = null;
  }

  void _toggleUseReal(bool v) async {
    if (v) {
      // switch to real
      await _subscribeToRealLocation();
      // stop mock subscription (we can keep mocking running in background if desired)
      _mockSub?.cancel();
    } else {
      // stop real stream and resume/subscribe to mock
      _unsubscribeRealLocation();
      if (_isMocking) _subscribeToMockStream();
    }
    setState(() {
      _useRealLocation = v;
    });
  }

  void _showSnack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Widget _positionCard() {
    if (_currentPosition == null) {
      return const Text('No position yet');
    }
    final p = _currentPosition!;
    return Column(
      children: [
        Text('Lat: ${p.latitude}'),
        Text('Lng: ${p.longitude}'),
        Text('Accuracy: ${p.accuracy} m'),
        Text('Time: ${p.timestamp}'),
      ],
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Input lat/lng
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _lat.toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) _lat = parsed;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    initialValue: _lng.toString(),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      if (parsed != null) _lng = parsed;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // mock start/stop & toggle real/mock
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isMocking ? null : () => _startMocking(),
                  child: const Text('Start Mock'),
                ),
                ElevatedButton(
                  onPressed: _isMocking ? _stopMocking : null,
                  child: const Text('Stop Mock'),
                ),
                Column(
                  children: [
                    const Text('Use real device location'),
                    Switch(
                      value: _useRealLocation,
                      onChanged: (v) => _toggleUseReal(v),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // current position display
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: _positionCard(),
              ),
            ),

            const SizedBox(height: 16),
            Text(
              'Mode: ${_useRealLocation ? 'Real device location' : (_isMocking ? 'Mocking (internal)' : 'Idle') }',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
                'Note: This only simulates location inside this Flutter app. Other apps will still see the device GPS.'),
          ],
        ),
      ),
    );
  }
}
