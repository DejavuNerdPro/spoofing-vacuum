import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
        
        colorScheme: ColorScheme.fromSeed(seedColor: Color.fromARGB(255, 3, 102, 122)),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
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
  final _lat = 16.85011;
  final _lng = 96.128573;
  Position? _currentPosition;
  String? _locationName = 'Idel';

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

    _emitMockPosition();

    _mockTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      _emitMockPosition();
    });

    _subscribeToMockStream();
    //_getReadablePosition();
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

  void _subscribeToMockStream() {
    _mockSub?.cancel();
    _mockSub = _mockController.stream.listen((pos) {
      setState(() {
        _currentPosition = pos;
      });
      //_getReadablePosition();
    });
  }

  // Subscribe to real device GPS stream (requires permissions)
  Future<void> _subscribeToRealLocation() async {
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
      //_getReadablePosition();
    }, onError: (e) {
      _showSnack('Error from location stream: $e');
    });
  }

  Future<void> _getReadablePosition() async{
    final placemarks =
          await placemarkFromCoordinates(_currentPosition!.latitude, _currentPosition!.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        setState(() {
          _locationName =
              "${place.name},${place.street},${place.locality}, ${place.administrativeArea}, ${place.country}";
        });
      }
  }

  void _unsubscribeRealLocation() {
    _realSub?.cancel();
    _realSub = null;
  }

  void _toggleUseReal(bool v) async {
    if (v) {
      // switch to real
      await _subscribeToRealLocation();
      _mockSub?.cancel();
    } else {
      _unsubscribeRealLocation();
      if (_isMocking) _subscribeToMockStream();
    }
    setState(() {
      _useRealLocation = v;
    });
    //_getReadablePosition();
  }

  void _showSnack(String s) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Widget _positionCard() {
    if (_currentPosition == null) {
      return const Text('GPS Matrix\n');
    }
    final p = _currentPosition!;
    return Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    // Table header
    Container(
      color: Color.fromARGB(255, 3, 102, 122),
      padding: const EdgeInsets.all(12),
      child: const Center(
        child: Text(
          'GPS Matrix',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    ),

    // Table body
    Table(
      border: TableBorder.all(color: Colors.grey),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
      },
      children: [
        TableRow(children: [
          const Padding(
            padding: EdgeInsets.all(6.0),
            child: Text("Latitude"),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Text("${p.latitude}"),
          ),
        ]),
        TableRow(children: [
          const Padding(
            padding: EdgeInsets.all(6.0),
            child: Text("Longitude"),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Text("${p.longitude}"),
          ),
        ]),
        TableRow(children: [
          const Padding(
            padding: EdgeInsets.all(6.0),
            child: Text("Accuracy"),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Text("${p.accuracy} m"),
          ),
        ]),
        TableRow(children: [
          const Padding(
            padding: EdgeInsets.all(6.0),
            child: Text("Time"),
          ),
          Padding(
            padding: const EdgeInsets.all(6.0),
            child: Text("${p.timestamp}"),
          ),
        ]),
      ],
    ),
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
            // Row(
            //   children: [
            //     Expanded(
            //       child: TextFormField(
            //         initialValue: _lat.toString(),
            //         keyboardType: const TextInputType.numberWithOptions(
            //             decimal: true, signed: true),
            //         decoration: const InputDecoration(labelText: 'Latitude'),
            //         readOnly: true,
            //         onChanged: (v) {
            //           final parsed = double.tryParse(v);
            //           if (parsed != null) _lat = parsed;
            //         },
            //       ),
            //     ),
            //     const SizedBox(width: 12),
            //     Expanded(
            //       child: TextFormField(
            //         initialValue: _lng.toString(),
            //         keyboardType: const TextInputType.numberWithOptions(
            //             decimal: true, signed: true),
            //         decoration: const InputDecoration(labelText: 'Longitude'),
            //         onChanged: (v) {
            //           final parsed = double.tryParse(v);
            //           if (parsed != null) _lng = parsed;
            //         },
            //       ),
            //     ),
            //   ],
            // ),
            // const SizedBox(height: 12),

            // mock start/stop & toggle real/mock
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isMocking ? null : () => _startMocking(),
                  child: const Text('Spoof'),
                ),
                ElevatedButton(
                  onPressed: _isMocking ? _stopMocking : null,
                  child: const Text('Stop'),
                ),
                const SizedBox(width: 30),
                Column(
                  children: [
                    Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const Text('Real GPS'),
                Switch(
                      value: _useRealLocation,
                      onChanged: (v) => _toggleUseReal(v),
                    ),
                        ],
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

            const SizedBox(height: 25),
            Text(
              'Mode: ${_useRealLocation ? 'Real device location' : (_isMocking ? 'Spoofing location' : 'Yet') }',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 50),
            const Text(
                'Note: This Simulator violates location inside the whole mobile system. Do not forget to release or stop it to be able to use other apps.',
                style: TextStyle(fontSize: 13),
                ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
    color: Colors.white,
    padding: const EdgeInsets.all(16),
    child: const Text(
      'Engineered by | Min Phyoe Min Thu',
      textAlign: TextAlign.center,
      style: TextStyle(color: Color.fromARGB(255, 3, 94, 89),fontSize: 10),
    ),
  ),
    );
  }
}
