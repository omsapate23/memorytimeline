import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui'; 
import 'dart:typed_data'; 
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart'; 

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final String id; 
  final String date;
  final String title;
  final String note;
  final double tilt;
  final String imageUrl;

  Memory({required this.id, required this.date, required this.title, required this.note, required this.tilt, required this.imageUrl});

  factory Memory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Memory(
      id: doc.id, 
      date: data['date'] ?? 'Unknown Date',
      title: data['title'] ?? 'Untitled Memory',
      note: data['note'] ?? '',
      tilt: (data['tilt'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'] ?? '',
    );
  }
}

// --- 2. THE MAIN PAGE ---
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key});

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  bool isAdmin = false;
  int titleTapCount = 0;
  DateTime lastTap = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isAdmin = prefs.getBool('isAdminDevice') ?? false;
    });
  }

  Future<void> _showAdminLogin() async {
    final passController = TextEditingController();
    bool wrongPass = false;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDF5E6),
              title: Text("Secret Door 🗝️", style: GoogleFonts.gochiHand(fontSize: 28, color: Colors.brown[800])),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Enter the creator passcode to unlock edit mode on this device.(Hint:first encounter)", style: GoogleFonts.caveat(fontSize: 20)),
                  TextField(
                    controller: passController, 
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Passcode",
                      errorText: wrongPass ? "Incorrect passcode" : null,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[400]),
                  onPressed: () async {
                    if (passController.text == '14102025') {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isAdminDevice', true);
                      if (context.mounted) {
                        setState(() => isAdmin = true);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Creator Mode Unlocked ✨"), backgroundColor: Colors.pink));
                      }
                    } else {
                      setDialogState(() => wrongPass = true);
                    }
                  },
                  child: const Text("Unlock", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  void _handleTitleTap() {
    final now = DateTime.now();
    if (now.difference(lastTap).inSeconds > 2) titleTapCount = 0; 
    lastTap = now;
    titleTapCount++;

    if (titleTapCount >= 3 && !isAdmin) {
      titleTapCount = 0;
      _showAdminLogin();
    }
  }

  Future<void> _deleteMemory(String memoryId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFDF5E6),
        title: Text("Delete Memory?", style: GoogleFonts.gochiHand(fontSize: 28, color: Colors.brown[800])),
        content: Text("Are you sure you want to tear this page out of the scrapbook?", style: GoogleFonts.caveat(fontSize: 20)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Keep it", style: TextStyle(color: Colors.brown))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[300]),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      )
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('memories').doc(memoryId).delete();
    }
  }

  Future<void> _showEditMemoryDialog(Memory memory) async {
    final titleController = TextEditingController(text: memory.title);
    final noteController = TextEditingController(text: memory.note);
    final dateController = TextEditingController(text: memory.date);
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
              title: Text("Edit Memory ✍️", style: GoogleFonts.gochiHand(fontSize: 28, color: Colors.brown[800])),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: dateController, decoration: const InputDecoration(labelText: "Date"), style: GoogleFonts.caveat(fontSize: 20)),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title"), style: GoogleFonts.caveat(fontSize: 20)),
                    TextField(controller: noteController, decoration: const InputDecoration(labelText: "Note"), maxLines: 3, style: GoogleFonts.caveat(fontSize: 20)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final bytes = await ImagePickerWeb.getImageAsBytes();
                        if (bytes != null) setState(() => selectedImageBytes = bytes);
                      },
                      icon: Icon(selectedImageBytes == null ? Icons.image : Icons.check_circle, color: Colors.white),
                      label: Text(selectedImageBytes == null ? "Change Image (Optional)" : "New Image Ready!", style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[400]),
                    ),
                    if (isUploading) const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.pinkAccent))
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isUploading ? null : () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.brown))),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (titleController.text.isEmpty) return;
                    setState(() => isUploading = true);

                    try {
                      String finalImageUrl = memory.imageUrl; 
                      
                      if (selectedImageBytes != null) {
                        final String base64Image = base64Encode(selectedImageBytes!);
                        final String apiKey = '1900287d47a36f5b9ef8a5882c3b9c19'; 
                        final Uri apiUrl = Uri.parse('https://api.imgbb.com/1/upload');
                        final response = await http.post(apiUrl, body: {'key': apiKey, 'image': base64Image});
                        final Map<String, dynamic> responseData = jsonDecode(response.body);
                        if (responseData['success'] == true) {
                          finalImageUrl = responseData['data']['display_url'] ?? responseData['data']['url'];
                        } else {
                          throw Exception(responseData['error']['message'] ?? "ImgBB Edit Upload Failed");
                        }
                      }

                      await FirebaseFirestore.instance.collection('memories').doc(memory.id).update({
                        'date': dateController.text,
                        'title': titleController.text,
                        'note': noteController.text,
                        'imageUrl': finalImageUrl,
                      });

                      if (context.mounted) Navigator.pop(context); 
                    } catch (e) {
                      print("🚨 EDIT UPLOAD ERROR: $e");
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Edit Failed: $e", style: const TextStyle(color: Colors.white)),
                            backgroundColor: Colors.red[400],
                            duration: const Duration(seconds: 5),
                          )
                        );
                      }
                      setState(() => isUploading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink[200]),
                  child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          }
        );
      }
    );
  }

  Future<void> _showAddMemoryDialog() async {
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
                    TextField(controller: dateController, decoration: const InputDecoration(labelText: "Date"), style: GoogleFonts.caveat(fontSize: 20)),
                    TextField(controller: titleController, decoration: const InputDecoration(labelText: "Title"), style: GoogleFonts.caveat(fontSize: 20)),
                    TextField(controller: noteController, decoration: const InputDecoration(labelText: "Note"), maxLines: 3, style: GoogleFonts.caveat(fontSize: 20)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final bytes = await ImagePickerWeb.getImageAsBytes();
                        if (bytes != null) setState(() => selectedImageBytes = bytes);
                      },
                      icon: Icon(selectedImageBytes == null ? Icons.image : Icons.check_circle, color: Colors.white),
                      label: Text(selectedImageBytes == null ? "Pick Local Image" : "Image Selected!", style: const TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.brown[400]),
                    ),
                    if (isUploading) const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(color: Colors.pinkAccent))
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: isUploading ? null : () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.brown))),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (selectedImageBytes == null || titleController.text.isEmpty) return;
                    setState(() => isUploading = true);
                    
                    try {
                      final String base64Image = base64Encode(selectedImageBytes!);
                      final String apiKey = '1900287d47a36f5b9ef8a5882c3b9c19'; 
                      final Uri apiUrl = Uri.parse('https://api.imgbb.com/1/upload');
                      
                      final response = await http.post(apiUrl, body: {
                        'key': apiKey, 
                        'image': base64Image
                      });
                      
                      final Map<String, dynamic> responseData = jsonDecode(response.body);

                      if (responseData['success'] == true) {
                        // Use the optimized display URL if available
                        final String imageUrl = responseData['data']['display_url'] ?? responseData['data']['url'];
                        final randomTilt = (math.Random().nextDouble() * 0.12) - 0.06;
                        
                        await FirebaseFirestore.instance.collection('memories').add({
                          'date': dateController.text,
                          'title': titleController.text,
                          'note': noteController.text,
                          'tilt': randomTilt,
                          'imageUrl': imageUrl,
                          'timestamp': Timestamp.now(), 
                        });
                        
                        if (context.mounted) Navigator.pop(context); 
                      } else {
                        throw Exception(responseData['error']['message'] ?? "ImgBB Upload Failed");
                      }
                    } catch (e) {
                      print("🚨 UPLOAD ERROR: $e"); 
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Upload Failed: $e", style: const TextStyle(color: Colors.white)),
                            backgroundColor: Colors.red[400],
                            duration: const Duration(seconds: 5),
                          )
                        );
                      }
                      setState(() => isUploading = false);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.pink[200]),
                  child: const Text("Upload to Timeline", style: TextStyle(color: Colors.white)),
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
        title: GestureDetector(
          onTap: _handleTitleTap,
          child: Text("our little memories ✨", style: GoogleFonts.gochiHand(fontSize: 34, color: Colors.brown[800])),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.08,
              child: Image.network('https://www.transparenttextures.com/patterns/paper-fibers.png', repeat: ImageRepeat.repeat, errorBuilder: (c, e, s) => const SizedBox()),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100), 
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('memories').orderBy('timestamp', descending: false).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.pinkAccent));

                  final memories = snapshot.data!.docs.map((doc) => Memory.fromFirestore(doc)).toList();

                  if (memories.isEmpty) {
                    return Center(child: Text(isAdmin ? "No memories yet! Click the camera to add one. 💖" : "No memories found.", style: GoogleFonts.caveat(fontSize: 28, color: Colors.brown[600])));
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
                                ? Padding(padding: const EdgeInsets.only(right: 60, left: 20), child: PolaroidCard(memory: memories[index], isAdmin: isAdmin, onEdit: () => _showEditMemoryDialog(memories[index]), onDelete: () => _deleteMemory(memories[index].id)))
                                : const SizedBox(), 
                            ),
                            Expanded(
                              child: !isLeft 
                                ? Padding(padding: const EdgeInsets.only(left: 60, right: 20), child: PolaroidCard(memory: memories[index], isAdmin: isAdmin, onEdit: () => _showEditMemoryDialog(memories[index]), onDelete: () => _deleteMemory(memories[index].id)))
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
      floatingActionButton: isAdmin ? FloatingActionButton(
        backgroundColor: Colors.pink[200],
        onPressed: _showAddMemoryDialog,
        child: const Icon(Icons.add_a_photo, color: Colors.white),
      ) : null,
    );
  }
}

// --- 3. THE POLAROID WIDGET ---
class PolaroidCard extends StatefulWidget {
  final Memory memory;
  final bool isAdmin; 
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PolaroidCard({super.key, required this.memory, required this.isAdmin, required this.onEdit, required this.onDelete});

  @override
  State<PolaroidCard> createState() => _PolaroidCardState();
}

class _PolaroidCardState extends State<PolaroidCard> {
  bool _isRevealed = false; 

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: widget.memory.tilt, 
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 12, offset: const Offset(4, 8))],
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
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isRevealed = !_isRevealed; 
                      });
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 250, 
                          width: double.infinity,
                          color: Colors.grey[200],
                          child: widget.memory.imageUrl.isEmpty 
                            ? const Center(child: Icon(Icons.favorite_border, color: Colors.grey, size: 50))
                            : Image.network(
                                widget.memory.imageUrl, 
                                fit: BoxFit.contain, 
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child; 
                                  return Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.pinkAccent[100],
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                                          : null,
                                    ),
                                  );
                                },
                              ),
                        ),
                        Positioned(
                          bottom: 8, right: 12,
                          child: Text(widget.memory.date.toUpperCase(), style: GoogleFonts.vt323(color: Colors.orangeAccent, fontSize: 22, shadows: [const Shadow(color: Colors.black, blurRadius: 3)])),
                        ),
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeInOutBack, 
                          bottom: _isRevealed ? -110 : -115, 
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: _isRevealed ? 0.0 : 1.0, 
                            child: SizedBox(
                              height: 205, 
                              width: 205,
                              child: Image.asset(
                                'assets/ribbon.png', 
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.favorite, color: Colors.pinkAccent),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  Text(
                    widget.memory.title, 
                    style: GoogleFonts.gochiHand(color: Colors.brown[900], fontSize: 28, fontWeight: FontWeight.bold)
                  ),
                  
                  AnimatedSize(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOutCubic,
                    alignment: Alignment.topCenter,
                    child: _isRevealed
                        ? Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(widget.memory.note, style: GoogleFonts.caveat(color: Colors.brown[700], fontSize: 22, height: 1.2)),
                          )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
                ],
              ),
            ),
            
            Positioned(top: -15, left: 0, right: 0, child: Center(child: Transform.rotate(angle: -0.06, child: Container(width: 80, height: 28, color: Colors.pink.withOpacity(0.35))))),
            
            if (widget.isAdmin)
              Positioned(
                top: 8, right: 8,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(color: Colors.black45, blurRadius: 4)]),
                  onSelected: (value) {
                    if (value == 'edit') widget.onEdit();
                    if (value == 'delete') widget.onDelete();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue, size: 20), SizedBox(width: 8), Text("Edit")])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text("Delete")])),
                  ],
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
    final paint = Paint()..color = Colors.brown.withOpacity(0.5)..strokeWidth = 3.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final w = size.width; final h = size.height;
    final startX = w / 2; final bowX = isLeft ? w * 0.35 : w * 0.65; 
    final path = Path()..moveTo(startX, 0)..cubicTo(startX, h * 0.25, bowX, h * 0.15, bowX, h * 0.5)..cubicTo(bowX, h * 0.85, startX, h * 0.75, startX, h);
    
    final dest = Path();
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        dest.addPath(metric.extractPath(distance, distance + 6.0), Offset.zero);
        distance += 12.0; 
      }
    }
    canvas.drawPath(dest, paint);

    if (!isLast) {
      final arrowPaint = Paint()..color = Colors.brown.withOpacity(0.7)..strokeWidth = 3.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round; 
      final arrowPath = Path()..moveTo(bowX - 10, (h * 0.5) - 10)..lineTo(bowX, h * 0.5)..lineTo(bowX + 10, (h * 0.5) - 10);
      canvas.drawPath(arrowPath, arrowPaint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}