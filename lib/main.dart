import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';

void main() => runApp(const MemoryApp());

class MemoryApp extends StatelessWidget {
  const MemoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text("My Memory Timeline")),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // First Node
            MemoryTile(
              isFirst: true,
              isLast: false,
              title: "The Beginning",
              note: "Started my first semester at AISSMS COE!",
              date: "Aug 2025",
            ),
            // Second Node
            MemoryTile(
              isFirst: false,
              isLast: true,
              title: "The Laser Project",
              note: "Built the Secure Optical Communication Link.",
              date: "April 2026",
            ),
          ],
        ),
      ),
    );
  }
}

class MemoryTile extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final String title;
  final String note;
  final String date;

  const MemoryTile({
    super.key, 
    required this.isFirst, 
    required this.isLast,
    required this.title,
    required this.note,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return TimelineTile(
      isFirst: isFirst,
      isLast: isLast,
      beforeLineStyle: const LineStyle(color: Colors.blue, thickness: 3),
      indicatorStyle: IndicatorStyle(
        width: 20,
        color: Colors.blue,
        padding: const EdgeInsets.all(6),
        iconStyle: IconStyle(color: Colors.white, iconData: Icons.circle),
      ),
      endChild: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(date, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(note),
            const SizedBox(height: 10),
            // Placeholder for an image
            Container(
              height: 100,
              width: double.infinity,
              color: Colors.blue.shade50,
              child: const Icon(Icons.image, color: Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}