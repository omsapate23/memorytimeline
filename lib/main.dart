import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; 
import 'dart:typed_data'; // For handling web image bytes
import 'dart:math' as math;

// Firebase Imports
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker_web/image_picker_web.dart';
import 'firebase_options.dart'; 

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MemoryTimelineApp());
}

class MemoryTimelineApp extends StatelessWidget {
  const MemoryTimelineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Our Scrapbook',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFDF5E6), 
      ),
      home: const TimelinePage(),
    );
  }
}

// --- 1. THE DATA MODEL ---
class Memory {
  final String date;
  final String title;
  final String note;
  final double tilt;
  final String imageUrl;

  Memory(this.date, this.title, this.note, this.tilt, this.imageUrl);

  factory Memory.fromFirestore(Map<String, dynamic> data) {
    return Memory(
      data['date'] ?? 'Unknown Date',
      data['title'] ?? 'Untitled Memory',
      data['note'] ?? '',
      (data['tilt'] ?? 0.0).toDouble(),
      data['imageUrl'] ?? '',
    );
  }
}

// --- 2. THE MAIN PAGE ---
class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  // --- THE ADMIN UPLOAD DIALOG ---
  Future<void> _showAddMemoryDialog(BuildContext context) async {
    final titleController = TextEditingController();
    final noteController = TextEditingController();
    final dateController = TextEditingController();
    Uint8List? selectedImageBytes;
    bool isUploading = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDF5E6),
              title: Text("Add a New Memory ✨", style: GoogleFonts.gochiHand(fontSize: 28, color: Colors.brown[800])),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: dateController, 
                      decoration: const InputDecoration(labelText: "Date (e.g. Aug 23, 2025)"),
                      style: GoogleFonts.caveat(fontSize: 20, color: Colors.brown[800]),
                    ),
                    TextField(
                      controller: titleController, 
                      decoration: const InputDecoration(labelText: "Title"),
                      style: GoogleFonts.caveat(fontSize: 20, color: Colors.brown[800]),
                    ),
                    TextField(
                      controller: noteController, 
                      decoration: const InputDecoration(labelText: "Note"), 
                      maxLines: 3,
                      style: GoogleFonts.caveat(fontSize: 20, color: Colors.brown[800]),
                    ),
                    const SizedBox(height: 20),
                    
                    // Image Picker Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        final bytes = await ImagePickerWeb.getImageAsBytes();
                        if (bytes != null) {
                          setState(() => selectedImageBytes = bytes);
                        }
                      },
                      icon: Icon(selectedImageBytes == null ? Icons.image : Icons.check_circle, color: Colors.white),
                      label: Text(
                        selectedImageBytes == null ? "Pick Local Image" : "Image Selected!",
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[400]),
                    ),
                    
                    if (isUploading) const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(color: Colors.pinkAccent),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.brown)),
                ),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (selectedImageBytes == null || titleController.text.isEmpty) return;

                    setState(() => isUploading = true);

                    try {
                      // 1. Generate unique filename
                      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
                      final storageRef = FirebaseStorage.instance.ref().child('memories/$fileName.jpg');

                      // 2. Upload to Firebase Storage
                      await storageRef.putData(selectedImageBytes!);

                      // 3. Get the public Download URL
                      final imageUrl = await storageRef.getDownloadURL();

                      // 4. Generate a random tilt for that scrapbook feel
                      final randomTilt = (math.Random().nextDouble() * 0.12) - 0.06;

                      // 5. Save to Firestore
                      await FirebaseFirestore.instance.collection('memories').add({
                        'date': dateController.text,
                        'title': titleController.text,
                        'note': noteController.text,
                        'tilt': randomTilt,
                        'imageUrl': imageUrl,
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) Navigator.pop(context); // Close dialog
                    } catch (e) {
                      print("Upload Error: $e");
                      setState(() => isUploading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink[200]),
                  child: const Text("Upload to Timeline", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "our little memories ✨",
          style: GoogleFonts.gochiHand(fontSize: 34, color: Colors.brown[800]),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Background Paper Texture
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Image.network(
                'https://www.transparenttextures.com/patterns/paper-fibers.png',
                repeat: ImageRepeat.repeat,
                errorBuilder: (context, error, stackTrace) => const SizedBox(), 
              ),
            ),
          ),
          
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100), 
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('memories')
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error loading memories: ${snapshot.error}'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
                  }

                  final docs = snapshot.data!.docs;
                  final memories = docs.map((doc) => Memory.fromFirestore(doc.data() as Map<String, dynamic>)).toList();

                  if (memories.isEmpty) {
                    return Center(
                      child: Text(
                        "No memories yet! Click the camera to add one. 💖",
                        style: GoogleFonts.caveat(fontSize: 28, color: Colors.brown[600]),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 20, bottom: 80),
                    itemCount: memories.length,
                    itemBuilder: (context, index) {
                      final isLeft = index % 2 == 0; 
                      final isLast = index == memories.length - 1;
                      
                      return CustomPaint(
                        painter: SmoothSweepingPainter(isLeft: isLeft, isLast: isLast),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: isLeft 
                                ? Padding(
                                    padding: const EdgeInsets.only(right: 60, left: 20),
                                    child: PolaroidCard(memory: memories[index]),
                                  )
                                : const SizedBox(), 
                            ),
                            Expanded(
                              child: !isLeft 
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 60, right: 20),
                                    child: PolaroidCard(memory: memories[index]),
                                  )
                                : const SizedBox(),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      // --- THE ADMIN UPLOAD BUTTON ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.pink[200],
        onPressed: () => _showAddMemoryDialog(context),
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ),
    );
  }
}

// --- 3. THE POLAROID WIDGET ---
class PolaroidCard extends StatelessWidget {
  final Memory memory;

  const PolaroidCard({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: memory.tilt, 
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(4, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    children: [
                      Container(
                        height: 250, 
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: memory.imageUrl.isEmpty 
                          ? const Center(child: Icon(Icons.favorite_border, color: Colors.grey, size: 50))
                          : Image.network(
                              memory.imageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 50));
                              },
                            ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 12,
                        child: Text(
                          memory.date.toUpperCase(),
                          style: GoogleFonts.vt323(
                            color: Colors.orangeAccent,
                            fontSize: 22,
                            shadows: [const Shadow(color: Colors.black, blurRadius: 3)],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    memory.title,
                    style: GoogleFonts.gochiHand(
                      color: Colors.brown[900],
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    memory.note,
                    style: GoogleFonts.caveat(
                      color: Colors.brown[700],
                      fontSize: 22,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -15,
              left: 0,
              right: 0,
              child: Center(
                child: Transform.rotate(
                  angle: -0.06,
                  child: Container(
                    width: 80,
                    height: 28,
                    color: Colors.pink.withOpacity(0.35),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 4. THE SMOOTH SWEEPING PAINTER ---
class SmoothSweepingPainter extends CustomPainter {
  final bool isLeft;
  final bool isLast;

  SmoothSweepingPainter({required this.isLeft, required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.brown.withOpacity(0.5)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    final startX = w / 2;
    final bowX = isLeft ? w * 0.35 : w * 0.65; 

    final path = Path();
    path.moveTo(startX, 0);

    path.cubicTo(
      startX, h * 0.25,  
      bowX, h * 0.15,    
      bowX, h * 0.5      
    );

    path.cubicTo(
      bowX, h * 0.85,    
      startX, h * 0.75,  
      startX, h          
    );

    final dottedPath = _createDashedPath(path, dashLength: 6.0, dashSpace: 6.0);
    canvas.drawPath(dottedPath, paint);

    if (!isLast) {
      final arrowPaint = Paint()
        ..color = Colors.brown.withOpacity(0.7)
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round; 

      final arrowPath = Path();
      arrowPath.moveTo(bowX - 10, (h * 0.5) - 10);
      arrowPath.lineTo(bowX, h * 0.5);
      arrowPath.lineTo(bowX + 10, (h * 0.5) - 10);
      
      canvas.drawPath(arrowPath, arrowPaint);
    }
  }

  Path _createDashedPath(Path source, {required double dashLength, required double dashSpace}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dest.addPath(
          metric.extractPath(distance, distance + dashLength),
          Offset.zero,
        );
        distance += dashLength + dashSpace;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}