import 'package:flutter/material.dart';

class KaraNotesPage extends StatelessWidget {
  final Map<String, List<String>> karaNotes;
  const KaraNotesPage({super.key, required this.karaNotes});

  @override
  Widget build(BuildContext context) {
    final entries = karaNotes.entries.where((e) => e.value.isNotEmpty).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kara40 Notes'),
        backgroundColor: Colors.transparent,
      ),
      body: entries.isEmpty
          ? const Center(child: Text('No notes available'))
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                final entry = entries[index];
                return Card(
                  color: const Color(0xFF161A23),
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.key,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                        const SizedBox(height: 10),
                        ...entry.value.map(
                          (n) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              '• $n',
                              style: const TextStyle(color: Colors.white70, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
