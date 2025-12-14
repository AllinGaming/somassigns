import 'package:flutter/material.dart';

class KaraNotesPage extends StatelessWidget {
  final Map<String, List<String>> karaNotes;
  const KaraNotesPage({super.key, required this.karaNotes});

  @override
  Widget build(BuildContext context) {
    final entries = karaNotes.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => MapEntry(e.key, e.value.toSet().toList()))
        .toList();
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
                  elevation: 2,
                  color: const Color(0xFF10131B),
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: Color(0xFF2B3242), width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(entry.key,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16)),
                            const SizedBox(width: 10),
                            Text('${entry.value.length} notes',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...entry.value.map(
                          (n) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('• ',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13)),
                                Expanded(
                                  child: Text(
                                    n,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        height: 1.3),
                                  ),
                                ),
                              ],
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
