import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: CameraWithDirection());
  }
}

class CameraWithDirection extends StatefulWidget {
  const CameraWithDirection({super.key});
  @override
  State<CameraWithDirection> createState() => _CameraWithDirectionState();
}

class _CameraWithDirectionState extends State<CameraWithDirection> {
  String _direction = 'N';
  final List<String> _directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
  double _degree = 0;
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  bool _permissionsGranted = false;
  double _compassOpacity = 0.5;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.locationWhenInUse,
    ].request();
    if (statuses[Permission.camera]!.isGranted && statuses[Permission.locationWhenInUse]!.isGranted) {
      setState(() {
        _permissionsGranted = true;
      });
      _initCamera();
      FlutterCompass.events?.listen((event) {
        final heading = event.heading;
        if (heading == null) return;
        double normalizedHeading = (heading < 0) ? (heading + 360) : heading;
        int index = ((normalizedHeading + 22.5) / 45).floor() % 8;
        setState(() {
          _direction = _directions[index];
          _degree = normalizedHeading;
        });
      });
    } else {
      setState(() {
        _permissionsGranted = false;
      });
    }
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    _controller = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller!.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: !_permissionsGranted
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock, color: Colors.white54, size: 60),
                  const SizedBox(height: 20),
                  const Text(
                    'Camera & Location permissions required',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _requestPermissions,
                    child: const Text('Grant Permissions'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                // Camera preview background
                _controller == null
                    ? const Center(child: CircularProgressIndicator())
                    : FutureBuilder<void>(
                        future: _initializeControllerFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.done) {
                            return FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width,
                                height: MediaQuery.of(context).size.height,
                                child: CameraPreview(_controller!),
                              ),
                            );
                          } else {
                            return const Center(child: CircularProgressIndicator());
                          }
                        },
                      ),
                // Compass UI overlay at top right with opacity
                Positioned(
                  top: 40,
                  right: 24,
                  child: Opacity(
                    opacity: _compassOpacity,
                    child: SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Rotating compass dial
                          Transform.rotate(
                            angle: -(_degree * (math.pi / 180)),
                            child: Container(
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.black.withOpacity(0.8),
                                    Colors.grey[900]!,
                                    Colors.black,
                                  ],
                                  radius: 0.9,
                                ),
                                border: Border.all(color: Colors.white24, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 16,
                                    offset: Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                painter: _CompassDialPainter(small: true),
                              ),
                            ),
                          ),
                          // Fixed needle (always down)
                          Container(
                            width: 100,
                            height: 100,
                            alignment: Alignment.bottomCenter, // changed from topCenter
                            child: Container(
                              width: 5,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.5),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Center degree and direction
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_degree.toStringAsFixed(0)}°',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black45,
                                      offset: Offset(2, 2),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _direction,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Opacity slider at the bottom
                Positioned(
                  left: 24,
                  right: 24,
                  bottom: 110,
                  child: Row(
                    children: [
                      const Icon(Icons.explore, color: Colors.white70),
                      Expanded(
                        child: Slider(
                          value: _compassOpacity,
                          min: 0.0,
                          max: 1.0,
                          divisions: 20,
                          label: '${(_compassOpacity * 100).toInt()}%',
                          onChanged: (value) {
                            setState(() {
                              _compassOpacity = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Capture button at the bottom center
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FloatingActionButton(
                      backgroundColor: Colors.white,
                      onPressed: () async {
                        if (_controller != null && _controller!.value.isInitialized) {
                          try {
                            final Directory extDir = await getTemporaryDirectory();
                            final String dirPath = '${extDir.path}/Pictures';
                            await Directory(dirPath).create(recursive: true);
                            final String filePath = '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';
                            await _controller!.takePicture().then((XFile file) async {
                              await file.saveTo(filePath);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Photo saved to $filePath')),
                                );
                              }
                            });
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      child: const Icon(Icons.camera_alt, size: 32, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// Custom painter for compass dial (tick marks and cardinal points)
class _CompassDialPainter extends CustomPainter {
  final bool small;
  _CompassDialPainter({this.small = false});
  @override
  void paint(Canvas canvas, Size size) {
    final Paint tickPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = small ? 1.2 : 2;
    final Paint cardinalPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = small ? 2 : 3;
    final double radius = size.width / 2;
    final center = Offset(radius, radius);
    // Draw tick marks
    for (int i = 0; i < 360; i += 10) {
      final double tickLength = (i % 90 == 0) ? (small ? 10 : 18) : (i % 30 == 0) ? (small ? 7 : 12) : (small ? 3 : 6);
      final double angle = (i - 90) * math.pi / 180;
      final Offset start = Offset(
        center.dx + (radius - (small ? 12 : 24)) * math.cos(angle),
        center.dy + (radius - (small ? 12 : 24)) * math.sin(angle),
      );
      final Offset end = Offset(
        center.dx + (radius - (small ? 12 : 24) - tickLength) * math.cos(angle),
        center.dy + (radius - (small ? 12 : 24) - tickLength) * math.sin(angle),
      );
      canvas.drawLine(start, end, (i % 90 == 0) ? cardinalPaint : tickPaint);
    }
    // Draw cardinal points
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: small ? 12 : 22,
      fontWeight: FontWeight.bold,
      shadows: [Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(1, 1))],
    );
    final List<String> cardinals = ['N', 'E', 'S', 'W'];
    for (int i = 0; i < 4; i++) {
      final double angle = (i * 90 - 90) * math.pi / 180;
      final Offset pos = Offset(
        center.dx + (radius - (small ? 24 : 48)) * math.cos(angle),
        center.dy + (radius - (small ? 24 : 48)) * math.sin(angle),
      );
      final textSpan = TextSpan(text: cardinals[i], style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      canvas.save();
      canvas.translate(pos.dx - textPainter.width / 2, pos.dy - textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
