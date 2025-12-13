import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'data.dart';
import 'kara_notes_page.dart';

void main() {
  runApp(const RaidApp());
}

class RaidApp extends StatelessWidget {
  const RaidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raid Assignments',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C7CFA),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0E1016),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white70),
          bodyLarge: TextStyle(color: Colors.white),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        cardColor: const Color(0xFF161A23),
      ),
      home: const RaidHome(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RaidHome extends StatefulWidget {
  const RaidHome({super.key});

  @override
  State<RaidHome> createState() => _RaidHomeState();
}

class _RaidHomeState extends State<RaidHome> {
  final SpreadsheetService _service = SpreadsheetService();
  RaidData? _data;
  bool _initialLoading = true;
  bool _refreshing = false;
  BossPlan? selected;
  Map<String, List<String>> karaNotes = const {};
  String searchQuery = '';
  Timer? _poller;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData(initial: true);
    _poller = Timer.periodic(const Duration(minutes: 2), (_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sons of Mukla'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.note, color: Colors.white),
              label: const Text('Kara40 Notes',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A3F4F),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onPressed: () {
                if (_data == null) return;
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => KaraNotesPage(karaNotes: karaNotes)),
                );
              },
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 1100;
          if (_initialLoading || _data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final bosses = _data!.bosses;
          karaNotes = _data!.karaNotes;
          selected ??= bosses.first;

          final searching = searchQuery.isNotEmpty;

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(isWide, bosses),
                if (searching) ...[
                  const SizedBox(height: 12),
                  _searchAssignments(bosses, fullScreen: true),
                ] else ...[
                  const SizedBox(height: 12),
                  _profileAndActions(),
                  if (selected!.extraImages.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _extraImagesRow(),
                  ],
                  const SizedBox(height: 12),
                    _buildTables(isWide),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadData({bool initial = false}) async {
    final currentName = selected?.name;
    if (!initial) setState(() => _refreshing = true);
    try {
      final data = await _service.loadPlans();
      final bosses = data.bosses;
      final match = currentName != null
          ? bosses.firstWhere((b) => b.name == currentName, orElse: () => bosses.first)
          : bosses.first;
      if (!mounted) return;
      setState(() {
        _data = data;
        selected = match;
        _initialLoading = false;
        _refreshing = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _refreshing = false;
      });
    }
  }

  @override
  void dispose() {
    _poller?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Widget _header(bool isWide, List<BossPlan> bosses) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Encounter', style: TextStyle(color: Colors.white70)),
        DropdownButton<BossPlan>(
          value: selected,
          dropdownColor: const Color(0xFF161A23),
          iconEnabledColor: Colors.white,
          items: bosses
              .map((b) => DropdownMenuItem(
                    value: b,
                    child: Text(b.name, style: const TextStyle(color: Colors.white)),
                  ))
              .toList(),
          onChanged: (plan) {
            if (plan != null) {
              setState(() {
                selected = plan;
                searchQuery = '';
                _searchController.clear();
              });
            }
          },
        ),
        if (isWide) const SizedBox(width: 24),
        Chip(
          label: const Text('Kara 40 Assignments',
              style: TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF222735),
        ),
        SizedBox(
          width: isWide ? 360 : double.infinity,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search your name for assignments',
                    filled: true,
                    fillColor: Color(0xFF161A23),
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) => setState(() => searchQuery = val.trim()),
                ),
              ),
              if (searchQuery.isNotEmpty) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() {
                    searchQuery = '';
                    _searchController.clear();
                  }),
                  icon: const Icon(Icons.clear, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF3A3F4F),
                    padding: const EdgeInsets.all(12),
                  ),
                  tooltip: 'Clear search',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(selected!.description,
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: selected!.highlights
                  .map((h) => Chip(
                        label: Text(h, style: const TextStyle(color: Colors.white70)),
                        backgroundColor: const Color(0xFF202637),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bossImage() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: SizedBox(
                height: 200,
                width: 200,
                child: Image.asset(
                  selected!.imageAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              selected!.name,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileAndActions() {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 800;
      if (isWide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _bossImage(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _actionButtons(),
                  if (selected!.notes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _buildNotes(),
                  ],
                ],
              ),
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bossImage(),
          const SizedBox(height: 8),
          _actionButtons(),
          if (selected!.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildNotes(),
          ],
        ],
      );
    });
  }

  Widget _actionButtons() {
    return const SizedBox.shrink();
  }

  Widget _extraImagesRow() {
    final isRupt = selected?.name.toLowerCase() == 'rupturan';
    final width = isRupt ? 520.0 : 460.0;
    final height = isRupt ? 260.0 : 280.0;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: selected!.extraImages
          .map((img) => GestureDetector(
                onTap: () => _openImageFullScreen(img, width, height),
                child: Stack(
                  children: [
                    Card(
                      color: const Color(0xFF161A23),
                      child: SizedBox(
                        height: height,
                        width: width,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(img, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Tap to zoom',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    )
                  ],
                ),
              ))
          .toList(),
    );
  }

  void _openImageFullScreen(String asset, double baseWidth, double baseHeight) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth * 0.95;
            final maxH = constraints.maxHeight * 0.95;
            final targetW = math.min(maxW, baseWidth * 2);
            final targetH = math.min(maxH, baseHeight * 2);
            return InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: SizedBox(
                width: targetW,
                height: targetH,
                child: Image.asset(asset, fit: BoxFit.contain),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTables(bool isWide) {
    final cards = selected!.tables
        .map((section) => SizedBox(
              width: isWide ? 520 : double.infinity,
              child: _tableCard(section),
            ))
        .toList();

    if (isWide) {
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards,
      );
    }
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i != cards.length - 1) const SizedBox(height: 12),
        ]
      ],
    );
  }

  Widget _tableCard(TableSection section) {
    final headers = section.headers;
    final rows = section.rows.map((r) {
      final filled = List<String>.filled(headers.length, '');
      for (var i = 0; i < r.length && i < headers.length; i++) {
        filled[i] = r[i];
      }
      return filled;
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (section.caption != null) ...[
              const SizedBox(height: 4),
              Text(section.caption!,
                  style: const TextStyle(color: Colors.white60, fontSize: 12)),
            ],
            const SizedBox(height: 8),
            _simpleTable(headers, rows),
          ],
        ),
      ),
    );
  }

  Widget _buildNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: selected!.notes
          .map((note) => Card(
                color: const Color(0xFF161A23),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFF5C7CFA), width: 1.2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(note.title,
                          style: const TextStyle(
                              color: Color(0xFF9BB5FF),
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                      const SizedBox(height: 8),
                      ...note.items
                          .map((i) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.star_rate_rounded,
                                        size: 16, color: Color(0xFF5C7CFA)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(i,
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15,
                                                height: 1.3))),
                                  ],
                                ),
                              ))
                          .toList(),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _simpleTable(List<String> headers, List<List<String>> rows) {
    return Table(
      columnWidths: {
        for (var i = 0; i < headers.length; i++) i: const FlexColumnWidth(),
      },
      border: TableBorder.symmetric(
        inside: const BorderSide(color: Color(0xFF202637)),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF1F2431)),
          children: headers
              .map((h) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(h,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ))
              .toList(),
        ),
        ...rows.map(
          (cells) => TableRow(
            decoration: const BoxDecoration(color: Color(0xFF141822)),
            children: cells
                .map((c) => Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(c, style: const TextStyle(color: Colors.white70)),
                    ))
                .toList(),
          ),
        )
      ],
    );
  }

  Widget _searchAssignments(List<BossPlan> bosses, {bool fullScreen = false}) {
    final query = searchQuery.toLowerCase();
    if (query.isEmpty) return const SizedBox.shrink();
    final hits = <Map<String, dynamic>>[];
    for (final boss in bosses) {
      for (final section in boss.tables) {
        bool sectionMatched = false;
        for (final row in section.rows) {
          if (row.any((cell) => cell.toLowerCase().contains(query))) {
            final bossName = boss.name.toLowerCase();
            // If Anomalus, show whole table once with highlighting.
            if (bossName == 'anomalus' && !sectionMatched) {
              hits.add({
                'boss': boss.name,
                'section': section.title,
                'fullTable': true,
                'headers': section.headers,
                'rows': section.rows,
                'image': boss.imageAsset,
                'query': query,
              });
              sectionMatched = true;
            } else if (bossName != 'gnarlmoon') {
              // For other bosses, show the full table with highlighted matches.
              if (!sectionMatched) {
                hits.add({
                  'boss': boss.name,
                  'section': section.title,
                  'fullTable': true,
                  'headers': section.headers,
                  'rows': section.rows,
                  'image': boss.imageAsset,
                  'query': query,
                });
                sectionMatched = true;
              }
            } else {
              String? detail;
              if (bossName == 'gnarlmoon') {
                final secLower = section.title.toLowerCase();
                if (secLower.contains('left')) {
                  detail = 'Left side';
                } else if (secLower.contains('right')) {
                  detail = 'Right side';
                } else if (secLower.contains('tanks')) {
                  final leftMatch = row.isNotEmpty && row[0].toLowerCase().contains(query);
                  final rightMatch = row.length > 1 && row[1].toLowerCase().contains(query);
                  if (leftMatch) detail = 'Left Tank';
                  if (rightMatch) detail = 'Right Tank';
                }
              }
              hits.add({
                'boss': boss.name,
                'section': section.title,
                'row': row.join(' | '),
                'image': boss.imageAsset,
                'detail': detail,
              });
            }
          }
          if (sectionMatched) break;
        }
      }
    }
    if (hits.isEmpty) {
      return const Text('No assignments found for that name.',
          style: TextStyle(color: Colors.white70));
    }
    final cards = hits
        .map((hit) => Card(
              color: const Color(0xFF161A23),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hit['image'] != null)
                          CircleAvatar(
                            radius: 18,
                            backgroundImage: AssetImage(hit['image']),
                          ),
                        if (hit['image'] != null) const SizedBox(width: 10),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF222735),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(hit['boss'],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3)),
                        ),
                        const SizedBox(width: 12),
                        Text(hit['section'],
                            style: const TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                                fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (hit['fullTable'] == true)
                      _highlightedTable(
                        List<String>.from(hit['headers'] as List),
                        (hit['rows'] as List<dynamic>)
                            .map<List<String>>((r) => List<String>.from(r as List))
                            .toList(),
                        hit['query'] as String,
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2B),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hit['row'],
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            if (hit['detail'] != null) ...[
                              const SizedBox(height: 4),
                              Text(hit['detail'],
                                  style: const TextStyle(
                                      color: Colors.white70,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 13)),
                            ]
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ))
        .toList();

    if (fullScreen) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Search Results',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...cards,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Search Results',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...cards,
      ],
    );
  }

  Widget _highlightedTable(
      List<String> headers, List<List<String>> rows, String query) {
    final lowerQuery = query.toLowerCase();
    return Table(
      columnWidths: {
        for (var i = 0; i < headers.length; i++) i: const FlexColumnWidth(),
      },
      border: TableBorder.symmetric(
        inside: const BorderSide(color: Color(0xFF202637)),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF1F2431)),
          children: headers
              .map((h) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(h,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ))
              .toList(),
        ),
        ...rows.map(
          (cells) => TableRow(
            decoration: const BoxDecoration(color: Color(0xFF141822)),
            children: cells
                .map((c) {
                  final isHit = c.toLowerCase().contains(lowerQuery);
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      c,
                      style: TextStyle(
                        color: isHit ? const Color(0xFFFFD166) : Colors.white,
                        fontWeight: isHit ? FontWeight.bold : FontWeight.normal,
                        fontSize: isHit ? 16 : 14,
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        )
      ],
    );
  }
}
