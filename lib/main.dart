import 'package:flutter/material.dart';
import 'package:timeline_tile/timeline_tile.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const MemoryTimelineApp());
}

class MemoryTimelineApp extends StatelessWidget {
  const MemoryTimelineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Memory Timeline',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0F0F0F), // Deep black
      ),
      home: const TimelinePage(),
    );
  }
}

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "OUR JOURNEY",
          style: GoogleFonts.montserrat(letterSpacing: 2, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topLeft,
            radius: 1.5,
            colors: [
              Colors.blueAccent.withOpacity(0.1),
              Colors.transparent,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          children: [
            const PremiumMemoryTile(
              isFirst: true,
              isLast: false,
              date: "AUGUST 2025",
              title: "The Beginning",
              note: "The first day of a new chapter. Everything felt new and the possibilities were endless.",
            ),
            const PremiumMemoryTile(
              isFirst: false,
              isLast: false,
              date: "DECEMBER 2025",
              title: "Winter Lights",
              note: "Exploring the city during the holidays. The lights were bright, but the company was better.",
            ),
            const PremiumMemoryTile(
              isFirst: false,
              isLast: true,
              date: "APRIL 2026",
              title: "Project Milestone",
              note: "Finally finished the prototype. Hard work pays off when you see the final result.",
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // This is where we will eventually trigger the PDF generation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("PDF Generation coming soon!")),
          );
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.picture_as_pdf, color: Colors.white),
      ),
    );
  }
}

class PremiumMemoryTile extends StatelessWidget {
  final bool isFirst;
  final bool isLast;
  final String date;
  final String title;
  final String note;

  const PremiumMemoryTile({
    super.key,
    required this.isFirst,
    required this.isLast,
    required this.date,
    required this.title,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return TimelineTile(
      isFirst: isFirst,
      isLast: isLast,
      beforeLineStyle: LineStyle(color: Colors.white.withOpacity(0.2), thickness: 2),
      indicatorStyle: IndicatorStyle(
        width: 35,
        height: 35,
        indicator: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blueAccent, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.blueAccent.withOpacity(0.4), blurRadius: 8)
            ],
          ),
          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
        ),
      ),
      endChild: Container(
        margin: const EdgeInsets.only(left: 20, bottom: 30),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              date,
              style: GoogleFonts.montserrat(
                color: Colors.blueAccent,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              note,
              style: GoogleFonts.lato(
                color: Colors.white.withOpacity(0.7),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // Mock Image Placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 200,
                width: double.infinity,
                color: Colors.white.withOpacity(0.1),
                child: Center(
                  child: Icon(Icons.image, color: Colors.white.withOpacity(0.2), size: 50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}