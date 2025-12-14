import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data.dart';
import 'kara_notes_page.dart';
import 'my_assigns_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
      scrollBehavior: const NoGlowBehavior(),
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const NoGlowBehavior(),
          child: child ?? const SizedBox.shrink(),
        );
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

class NoGlowBehavior extends ScrollBehavior {
  const NoGlowBehavior();

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
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
  // ignore: unused_field
  bool _refreshing = false;
  bool _showSearch = false;
  BossPlan? selected;
  Map<String, List<String>> karaNotes = const {};
  String searchQuery = '';
  Timer? _poller;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _charNameController = TextEditingController();
  String _charClass = 'Warrior';
  String _charRole = 'Melee DPS';
  List<Map<String, String>> _characters = [];
  int _currentCharIndex = 0;
  static const _charListKey = 'char_list';
  static const _charIndexKey = 'char_index';
  final List<String> _classes = const [
    'Warrior',
    'Paladin',
    'Hunter',
    'Rogue',
    'Priest',
    'Shaman',
    'Mage',
    'Warlock',
    'Druid',
  ];
  final List<String> _roles = const ['Tank', 'Healer', 'Melee DPS', 'Ranged DPS'];

  @override
  void initState() {
    super.initState();
    _loadData(initial: true);
    _poller = Timer.periodic(const Duration(seconds: 45), (_) => _loadData());
    _loadCharacter().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _charNameController.text.trim().isEmpty) {
          _showCharacterDialog(editing: false);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
      title: _header(MediaQuery.of(context).size.width > 1100, _data?.bosses ?? []),
        centerTitle: false,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: _charNameController.text.trim().isNotEmpty &&
              (_data?.bosses.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFB23A48),
              icon: const Icon(Icons.assignment_turned_in),
              label: const Text('My Assignments'),
              onPressed: _openMyAssignments,
            )
          : null,
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
                const SizedBox(height: 8),
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

  Future<void> _loadCharacter() async {
    final prefs = await SharedPreferences.getInstance();
    final storedList = prefs.getString(_charListKey);
    List<Map<String, String>> parsedList = [];
    int index = 0;
    if (storedList != null && storedList.isNotEmpty) {
      final parsed = jsonDecode(storedList) as List<dynamic>;
      parsedList = parsed
          .map((e) => (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
          .toList();
      index = prefs.getInt(_charIndexKey) ?? 0;
    } else {
      final legacyName = prefs.getString('char_name') ?? '';
      final legacyClass = prefs.getString('char_class') ?? 'Warrior';
      final legacyRole = prefs.getString('char_role') ?? 'Melee DPS';
      if (legacyName.isNotEmpty) {
        parsedList = [
          {'name': legacyName, 'class': legacyClass, 'role': legacyRole}
        ];
      }
    }

    setState(() {
      _characters = parsedList;
      _currentCharIndex = index.clamp(0, _characters.isEmpty ? 0 : _characters.length - 1);
    });

    if (_characters.isNotEmpty) {
      _setCurrentCharacter(_currentCharIndex);
    } else {
      setState(() {
        _charNameController.text = '';
        _charClass = 'Warrior';
        _charRole = 'Melee DPS';
      });
    }
  }

  Future<int> _saveCharacter({bool editing = true, int? index}) async {
    final prefs = await SharedPreferences.getInstance();
    final entry = {
      'name': _charNameController.text.trim(),
      'class': _charClass,
      'role': _charRole,
    };
    int newIndex = 0;
    setState(() {
      if (editing && _characters.isNotEmpty) {
        final idx = (index ?? _currentCharIndex).clamp(0, _characters.length - 1);
        _characters[idx] = entry;
        _currentCharIndex = idx;
        newIndex = idx;
      } else {
        _characters.add(entry);
        _currentCharIndex = _characters.length - 1;
        newIndex = _currentCharIndex;
      }
    });
    await prefs.setString(_charListKey, jsonEncode(_characters));
    await prefs.setInt(_charIndexKey, _currentCharIndex);
    await prefs.setString('char_name', entry['name'] ?? '');
    await prefs.setString('char_class', entry['class'] ?? 'Warrior');
    await prefs.setString('char_role', entry['role'] ?? 'Melee DPS');
    return newIndex;
  }

  Future<void> _setCurrentCharacter(int index) async {
    if (_characters.isEmpty) return;
    final idx = index.clamp(0, _characters.length - 1);
    _currentCharIndex = idx;
    final current = _characters[idx];
    setState(() {
      _charNameController.text = current['name'] ?? '';
      _charClass = current['class'] ?? 'Warrior';
      _charRole = current['role'] ?? 'Melee DPS';
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_charIndexKey, _currentCharIndex);
  }
  void _showCharacterDialog({bool editing = true, int? index}) {
    if (editing && _characters.isNotEmpty) {
      final idx = (index ?? _currentCharIndex).clamp(0, _characters.length - 1);
      final current = _characters[idx];
      _charNameController.text = current['name'] ?? '';
      _charClass = current['class'] ?? 'Warrior';
      _charRole = current['role'] ?? 'Melee DPS';
      _currentCharIndex = idx;
    } else {
      _charNameController.text = '';
      _charClass = 'Warrior';
      _charRole = 'Melee DPS';
    }
    showDialog(
      context: context,
      builder: (context) {
        String tempClass = _charClass;
        String tempRole = _charRole;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: const Color(0xFF161A23),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: const Text('Save Character',
                  style: TextStyle(color: Colors.white)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _charNameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      filled: true,
                      fillColor: Color(0xFF1E2330),
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tempClass,
                    dropdownColor: const Color(0xFF161A23),
                    decoration: const InputDecoration(
                      labelText: 'Class',
                      filled: true,
                      fillColor: Color(0xFF1E2330),
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                    ),
                    items: _classes
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, style: const TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() => tempClass = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: tempRole,
                    dropdownColor: const Color(0xFF161A23),
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      filled: true,
                      fillColor: Color(0xFF1E2330),
                      labelStyle: TextStyle(color: Colors.white70),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(10))),
                    ),
                    items: _roles
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(r, style: const TextStyle(color: Colors.white)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setStateDialog(() => tempRole = val);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _charClass = tempClass;
                      _charRole = tempRole;
                    });
                    _saveCharacter(editing: editing, index: index ?? _currentCharIndex)
                        .then((idx) {
                      _setCurrentCharacter(idx);
                      Navigator.of(context).pop();
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C7CFA),
                  ),
                  child:
                      const Text('Save', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCharacterPicker() {
    if (_characters.isEmpty) {
      _showCharacterDialog(editing: false);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161A23),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14))),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Select character',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 8),
                ...List.generate(_characters.length, (i) {
                  final name = _characters[i]['name'] ?? '';
                  final cls = _characters[i]['class'] ?? '';
                  final role = _characters[i]['role'] ?? '';
                  return ListTile(
                    title: Text(name,
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                    subtitle: Text('$cls • $role',
                        style: const TextStyle(color: Colors.white70)),
                    trailing: i == _currentCharIndex
                        ? const Icon(Icons.check, color: Color(0xFF5C7CFA))
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      _setCurrentCharacter(i);
                    },
                  );
                }),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showCharacterDialog(editing: false);
                  },
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add character'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C7CFA)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _header(bool isWide, List<BossPlan> bosses) {
    if (bosses.isEmpty) return const SizedBox.shrink();
    final hasChar = _charNameController.text.trim().isNotEmpty;
    final initials = hasChar ? _charNameController.text.trim()[0].toUpperCase() : '';
    const isCompactHeader = false; // unified layout; horizontal scroll handles overflow
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_showSearch) ...[
          Row(
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
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() {
                  searchQuery = '';
                  _searchController.clear();
                  _showSearch = false;
                }),
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF3A3F4F),
                  padding: const EdgeInsets.all(12),
                ),
                tooltip: 'Close search',
              ),
            ],
          ),
        ] else ...[
          Builder(builder: (context) {
            final searchButton = IconButton(
              tooltip: 'Search assignments',
              icon: const Icon(Icons.search, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF3A3F4F)),
              onPressed: () {
                setState(() {
                  _showSearch = true;
                });
              },
            );

            const dropDownWidth = 130.0;
            final navControls = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Previous encounter',
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF3A3F4F)),
                  onPressed: () {
                    if (selected == null || bosses.isEmpty) return;
                    final current = bosses.indexOf(selected!);
                    _selectBoss(bosses, current - 1);
                    setState(() {
                      searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161A23),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF2B3242)),
                  ),
                  child: SizedBox(
                    width: dropDownWidth,
                    child: DropdownButton<BossPlan>(
                      isExpanded: true,
                      value: selected,
                      dropdownColor: const Color(0xFF161A23),
                      underline: const SizedBox(),
                      iconEnabledColor: Colors.white,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      onChanged: (plan) {
                        if (plan != null) {
                          setState(() {
                            selected = plan;
                            searchQuery = '';
                            _searchController.clear();
                          });
                        }
                      },
                      items: bosses
                          .map((b) => DropdownMenuItem(
                                value: b,
                                child: Text(b.name, overflow: TextOverflow.ellipsis),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Next encounter',
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF3A3F4F)),
                  onPressed: () {
                    if (selected == null || bosses.isEmpty) return;
                    final current = bosses.indexOf(selected!);
                    _selectBoss(bosses, current + 1);
                    setState(() {
                      searchQuery = '';
                      _searchController.clear();
                    });
                  },
                ),
              ],
            );

            final charControl = hasChar
                ? Tooltip(
                    message: 'Edit / switch character',
                    child: PopupMenuButton<String>(
                      tooltip: '',
                      offset: const Offset(0, 40),
                      color: const Color(0xFF1A1F2B),
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      onSelected: (val) {
                        if (val == 'edit') {
                          _showCharacterDialog(editing: true, index: _currentCharIndex);
                        } else if (val == 'switch') {
                          _showCharacterPicker();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'switch',
                          child: Text('Change character',
                              style: TextStyle(color: Colors.white)),
                        ),
                        PopupMenuItem(
                          value: 'edit',
                          child:
                              Text('Edit character', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: const Color(0xFF5C7CFA),
                        child: Text(initials,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Add character',
                    icon: const Icon(Icons.person_add, color: Colors.white),
                    style: IconButton.styleFrom(backgroundColor: const Color(0xFF3A3F4F)),
                    onPressed: () => _showCharacterDialog(editing: false),
                  );

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                searchButton,
                const SizedBox(width: 12),
                Expanded(
                  child: Center(child: navControls),
                ),
                const SizedBox(width: 12),
                charControl,
              ],
            );
          }),
        ],
      ],
    );
  }

  void _openMyAssignments() {
    final name = _charNameController.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MyAssignsPage(
              bosses: _data?.bosses ?? [],
              name: name,
              charClass: _charClass,
              role: _charRole,
            )));
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

  void _selectBoss(List<BossPlan> bosses, int index) {
    if (bosses.isEmpty) return;
    final wrapped = (index % bosses.length + bosses.length) % bosses.length;
    setState(() {
      selected = bosses[wrapped];
    });
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
            // For Anomalus and other bosses (except Gnarlmoon), show full table once.
            if (bossName != 'gnarlmoon' && !sectionMatched) {
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
            } else if (bossName == 'gnarlmoon') {
              String? detail;
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
