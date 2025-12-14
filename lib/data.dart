import 'dart:convert';
import 'package:http/http.dart' as http;

const _sheetId = '1SlLl2Ly6zqP5_PpQKdhEoefv96_LyCUpf0dRyQfcfAE';

class TableSection {
  final String title;
  final List<String> headers;
  final List<List<String>> rows;
  final String? caption;

  const TableSection({
    required this.title,
    required this.headers,
    required this.rows,
    this.caption,
  });
}

class NoteBlock {
  final String title;
  final List<String> items;

  const NoteBlock({required this.title, required this.items});
}

class BossPlan {
  final String name;
  final String description;
  final List<String> highlights;
  final List<TableSection> tables;
  final List<NoteBlock> notes;
  final String imageAsset;
  final List<String> extraImages;

  const BossPlan({
    required this.name,
    required this.description,
    required this.highlights,
    required this.tables,
    required this.notes,
    required this.imageAsset,
    this.extraImages = const [],
  });
}

class RaidData {
  final List<BossPlan> bosses;
  final Map<String, List<String>> karaNotes;
  const RaidData({required this.bosses, required this.karaNotes});
}

class SpreadsheetService {
  final http.Client _client;
  SpreadsheetService({http.Client? client}) : _client = client ?? http.Client();

  Future<RaidData> loadPlans() async {
    final sheets = await _fetchSheets();
    final notes = await _fetchNotes();
    final bosses = [
      _buildGnarlmoon(sheets['Gnarlmoon'] ?? const [], notes),
      _buildLeyWatcher(sheets['Ley-Watcher Incantagos'] ?? const [], notes),
      _buildAnomalus(sheets['Anomalus'] ?? const [], notes),
      _buildEcho(sheets['Echo of Medivh'] ?? const [], notes),
      _buildChess(sheets['Chess'] ?? const [], notes),
      _buildSanv(sheets['Sanv'] ?? const [], notes),
      _buildRupturan(sheets['Rupturan'] ?? const [], notes),
      _buildKruul(sheets['Kruul'] ?? const [], notes),
      _buildMeph(sheets['Mephistroth'] ?? const [], notes),
    ];
    return RaidData(bosses: bosses, karaNotes: notes);
  }

  Future<Map<String, List<List<String>>>> _fetchSheets() async {
    const names = [
      'Gnarlmoon',
      'Ley-Watcher Incantagos',
      'Anomalus',
      'Echo of Medivh',
      'Chess',
      'Sanv',
      'Rupturan',
      'Kruul',
      'Mephistroth',
    ];
    final results = <String, List<List<String>>>{};
    for (final name in names) {
      try {
        results[name] = await _fetchSheet(name);
      } catch (_) {
        results[name] = const [];
      }
    }
    return results;
  }

  Future<List<List<String>>> _fetchSheet(String sheetName) async {
    final uri = Uri.parse(
        'https://docs.google.com/spreadsheets/d/$_sheetId/gviz/tq?tqx=out:json&sheet=$sheetName');
    final res = await _client.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Failed to load $sheetName');
    }
    final body = res.body;
    final start = body.indexOf('{');
    final end = body.lastIndexOf('}');
    if (start == -1 || end == -1) {
      throw Exception('Bad response for $sheetName');
    }
    final jsonStr = body.substring(start, end + 1);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final table = data['table'] as Map<String, dynamic>;
    final rows = (table['rows'] as List<dynamic>)
        .map((row) => (row['c'] as List<dynamic>?)
                ?.map((c) => c == null ? '' : (c['v']?.toString() ?? ''))
                .toList() ??
            <String>[])
        .toList();
    return rows;
  }

  Future<Map<String, List<String>>> _fetchNotes() async {
    final uri = Uri.parse(
        'https://docs.google.com/spreadsheets/d/$_sheetId/gviz/tq?tqx=out:json&sheet=Kara40%20Notes');
    final res = await _client.get(uri);
    if (res.statusCode != 200) return {};
    final body = res.body;
    final start = body.indexOf('{');
    final end = body.lastIndexOf('}');
    if (start == -1 || end == -1) return {};
    final jsonStr = body.substring(start, end + 1);
    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
    final table = data['table'] as Map<String, dynamic>;
    final rows = (table['rows'] as List<dynamic>)
        .map((row) => (row['c'] as List<dynamic>?)
                ?.map((c) => c == null ? '' : (c['v']?.toString() ?? ''))
                .toList() ??
            <String>[])
        .toList();

    final noteMap = <String, List<String>>{};
    for (final r in rows) {
      if (r.isEmpty) continue;
      final title = r[0].trim();
      final note = r.length > 1 ? r[1].trim() : '';
      if (title.isEmpty || note.isEmpty) continue;
      final key = title.toLowerCase();
      noteMap.putIfAbsent(key, () => []).add('$title: $note');

      // Also bucket notes under boss keys when title contains them (for per-boss display).
      for (final bossKey in [
        'gnarlmoon',
        'ley-watcher incantagos',
        'anomalus',
        'echo of medivh',
        'chess',
        'sanv',
        'rupturan',
        'kruul',
        'mephistroth'
      ]) {
        if (key.contains(bossKey)) {
          noteMap.putIfAbsent(bossKey, () => []).add('$title: $note');
        }
      }
    }
    return noteMap;
  }
}

String _cell(List<List<String>> rows, int r, int c) {
  if (r < 0 || r >= rows.length) return '';
  final row = rows[r];
  if (c < 0 || c >= row.length) return '';
  final val = row[c];
  return val == 'null' ? '' : val;
}

int _findRow(List<List<String>> rows, String text) {
  return rows.indexWhere(
      (r) => r.any((c) => c.toLowerCase() == text.toLowerCase()));
}

List<String> _notesFor(Map<String, List<String>> notes, String key) =>
    notes[key] ?? const [];

List<String> _notesForContains(
    Map<String, List<String>> notes, String keyPart, String extraPart) {
  final lowerKey = keyPart.toLowerCase();
  final lowerExtra = extraPart.toLowerCase();
  final collected = <String>[];
  notes.forEach((k, v) {
    final lk = k.toLowerCase();
    if (lk.contains(lowerKey) && lk.contains(lowerExtra)) {
      collected.addAll(v);
    }
  });
  return collected;
}

BossPlan _buildGnarlmoon(List<List<String>> rows, Map<String, List<String>> notes) {
  final left = <String>[];
  final right = <String>[];
  for (var i = 1; i < rows.length; i++) {
    final l = _cell(rows, i, 1).trim();
    final r = _cell(rows, i, 3).trim();
    if (l.isNotEmpty) left.add(l);
    if (r.isNotEmpty) right.add(r);
    if (i > 20 && l.isEmpty && r.isEmpty) break;
  }

  final tankHealers = <String>[];
  for (var i = 1; i < 8 && i < rows.length; i++) {
    final name = _cell(rows, i, 6);
    if (name.isNotEmpty && name.toLowerCase() != 'tank healer') {
      tankHealers.add(name);
    }
  }

  final tankCoreLeft = <String>[];
  final tankCoreRight = <String>[];
  for (var i = 23; i <= 24 && i < rows.length; i++) {
    final l = _cell(rows, i, 1);
    final r = _cell(rows, i, 3);
    if (l.isNotEmpty) tankCoreLeft.add(l);
    if (r.isNotEmpty) tankCoreRight.add(r);
  }

  return BossPlan(
    name: 'Gnarlmoon',
    description:
        'Left vs Right split. Counts show bodies per side; keep tanks and healers balanced.',
    highlights: [
      'Left target: ${_cell(rows, 0, 0)}',
      'Right target: ${_cell(rows, 0, 4)}',
      if (tankHealers.isNotEmpty) 'Tank healers: ${tankHealers.join(', ')}',
    ],
    tables: [
      TableSection(
        title: 'Left Side',
        headers: ['Player'],
        rows: [
          for (var i = 0; i < left.length; i++) [left[i]],
        ],
        caption: 'Pulled live from Gnarlmoon sheet (left column).',
      ),
      TableSection(
        title: 'Right Side',
        headers: ['Player'],
        rows: [
          for (var i = 0; i < right.length; i++) [right[i]],
        ],
        caption: 'Pulled live from Gnarlmoon sheet (right column).',
      ),
      TableSection(
        title: 'Tanks',
        headers: ['Left', 'Right'],
        rows: [
          [
            tankCoreLeft.isNotEmpty ? tankCoreLeft.join(', ') : '—',
            tankCoreRight.isNotEmpty ? tankCoreRight.join(', ') : '—'
          ],
        ],
      ),
      TableSection(
        title: 'Tank Healers',
        headers: ['Players'],
        rows: [
          [tankHealers.join(', ')],
        ],
      ),
    ],
    notes: [
      NoteBlock(title: 'Magic', items: ['Dampen Magic on non-tanks.']),
      if (_notesFor(notes, 'gnarlmoon').isNotEmpty)
        NoteBlock(title: 'Kara notes', items: _notesFor(notes, 'gnarlmoon')),
    ],
    imageAsset: 'assets/gnarlmoon.png',
    extraImages: const [],
  );
}

BossPlan _buildAnomalus(List<List<String>> rows, Map<String, List<String>> notes) {
  // Healers: rows after header (row 2) until the "Tanks" marker (row 6)
  final healerRows = <List<String>>[];
  final headerRow = _findRow(rows, 'Group 1 & 2');
  if (headerRow != -1) {
    for (var i = headerRow + 1; i < rows.length; i++) {
      final isTanksMarker =
          rows[i].isNotEmpty && rows[i][0].toLowerCase() == 'tanks';
      if (isTanksMarker) break;
      if (rows[i].where((c) => c.trim().isNotEmpty).isEmpty) continue;
      final filled = List<String>.filled(5, '');
      for (var j = 0; j < 5 && j < rows[i].length; j++) {
        filled[j] = rows[i][j];
      }
      healerRows.add(filled);
    }
  }

  // Tank order: rows following the "Tanks" marker until a blank line.
  final tankAssignments = <List<String>>[];
  final tankHeaderRow =
      rows.indexWhere((r) => r.isNotEmpty && r[0].trim().toLowerCase() == 'tanks');
  if (tankHeaderRow != -1) {
    for (var r = tankHeaderRow + 1; r < rows.length; r++) {
      final tank = _cell(rows, r, 0);
      final order = _cell(rows, r, 1);
      if (tank.trim().isEmpty && order.trim().isEmpty) break;
      if (tank.trim().isEmpty && order.trim().isEmpty) continue;
      tankAssignments.add([tank, order]);
    }
  }

  final tankHealers = <String>[];
  // After group 7 & 8 (row indices 3-5), column 4 holds tank healers
  for (var i = 3; i <= 5 && i < rows.length; i++) {
    final healer = _cell(rows, i, 4);
    if (healer.isNotEmpty && healer.toLowerCase() != 'tanks') {
      tankHealers.add(healer);
    }
  }

  return BossPlan(
    name: 'Anomalus',
    description:
        'Group healing assignments plus tank rotation. Tanks section mirrors the sheet block after group 7 & 8.',
    highlights: [
      'Group 1-4 have dedicated healers',
      'Tanks listed under Group 1 & 2 with positions beside them',
      'Tank healers shown in the Tanks column',
    ],
    tables: [
      TableSection(
        title: 'Healer Layout',
        headers: ['Group 1 & 2', 'Group 3 & 4', 'Group 5 & 6', 'Group 7 & 8', 'Tanks'],
        rows: healerRows,
      ),
      if (tankAssignments.isNotEmpty)
        TableSection(
          title: 'Tank Order',
          headers: ['Tank', 'Order'],
          rows: tankAssignments,
          caption: 'Taken from the Tanks block (Nubbie, Sniej, Tijana).',
        ),
      if (tankHealers.isNotEmpty)
        TableSection(
          title: 'Tank Healers',
          headers: ['Healer', 'Tanks'],
          rows: [
            for (var i = 0; i < tankHealers.length; i++)
              [
                tankHealers[i],
                tankAssignments.isNotEmpty
                    ? tankAssignments.map((t) => t[0]).join(', ')
                    : 'Nubbie, Sniej, Tijana'
              ],
          ],
          caption: 'Healers assigned to tanks (from column next to Group 7 & 8).',
        ),
      TableSection(
        title: 'Magic',
        headers: ['Call', 'Targets'],
        rows: const [
          ['Dampen Magic', 'Non-tanks'],
        ],
      ),
    ],
    notes: [
      NoteBlock(title: 'Buffs', items: ['Apply Dampen Magic on non-tanks.']),
      if (_notesFor(notes, 'anomalus').isNotEmpty)
        NoteBlock(title: 'Kara notes', items: _notesFor(notes, 'anomalus')),
    ],
    imageAsset: 'assets/anomalus.png',
    extraImages: const [],
  );
}

BossPlan _buildChess(List<List<String>> rows, Map<String, List<String>> notes) {
  List<TableSection> phase(String name) {
    final headRow = _findRow(rows, name);
    if (headRow == -1) return [];
    final pieceRow = rows[headRow];
    final roleRow = headRow + 1 < rows.length ? rows[headRow + 1] : const [];
    int nextPhase = rows.length;
    for (var i = headRow + 1; i < rows.length; i++) {
      if (rows[i].any((c) => c.toString().toLowerCase().contains('phase'))) {
        nextPhase = i;
        break;
      }
    }
    final dataRows = rows.sublist(headRow + 2, nextPhase);

    // map each column to the latest piece name above it
    final pieceForCol = <int, String>{};
    String current = '';
    for (var c = 0; c < pieceRow.length; c++) {
      final nameCell = pieceRow[c].toString();
      if (nameCell.trim().isNotEmpty) current = nameCell;
      pieceForCol[c] = current;
    }

    final roles = <int, String>{};
    for (var c = 0; c < roleRow.length; c++) {
      final role = roleRow[c].toString();
      if (role.trim().isNotEmpty) roles[c] = role;
    }

    final collected = <String, Map<String, List<String>>>{};
    for (final row in dataRows) {
      for (var c = 0; c < row.length; c++) {
        final val = row[c].toString();
        if (val.trim().isEmpty) continue;
        final piece = pieceForCol[c] ?? '';
        if (piece.isEmpty) continue;
        final role = roles[c] ?? 'Extra';
        collected.putIfAbsent(piece, () => {});
        collected[piece]!.putIfAbsent(role, () => []).add(val);
      }
    }

    final data = <List<String>>[];
    collected.forEach((piece, roleMap) {
      final tanks = roleMap['Tank'] ?? [];
      final healers = roleMap['Healer'] ?? [];
      final extras = roleMap.entries
          .where((e) => e.key != 'Tank' && e.key != 'Healer')
          .expand((e) => e.value)
          .toList();

      final maxRows = [tanks.length, healers.length, extras.length].fold<int>(
          0, (prev, e) => e > prev ? e : prev);
      final rows = maxRows == 0 ? 1 : maxRows;

      for (var i = 0; i < rows; i++) {
        data.add([
          piece,
          i < tanks.length ? tanks[i] : '',
          i < healers.length ? healers[i] : '',
          i < extras.length ? extras[i] : '',
        ]);
      }
    });

    return [
      TableSection(
        title: name,
        headers: ['Piece', 'Tank', 'Healer', 'DPS / Extra'],
        rows: data,
      )
    ];
  }

  final p1 = phase('Phase 1');
  final p2 = phase('Phase 2');
  final p3 = phase('Phase 3');

  return BossPlan(
    name: 'Chess',
    description: 'Phase-by-phase board control with tanks/healers on pieces.',
    highlights: [
      'Three phases mapped from sheet',
      'Dedicated healer per key piece',
      'Dampen Magic on non-tanks only',
    ],
    tables: [
      ...p1,
      ...p2,
      ...p3,
      TableSection(
        title: 'Magic',
        headers: ['Call'],
        rows: const [
          ['Dampen Magic'],
          ['Non-tanks only'],
        ],
      ),
    ],
    notes: [
      if (_notesFor(notes, 'chess').isNotEmpty)
        NoteBlock(title: 'Kara notes', items: _notesFor(notes, 'chess')),
    ],
    imageAsset: 'assets/chess.png',
    extraImages: const [],
  );
}

BossPlan _buildSanv(List<List<String>> rows, Map<String, List<String>> notes) {
  return BossPlan(
    name: "Sanv Tas'dal",
    description:
        'Split between boss platform and staircase with backup and portal teams.',
    highlights: [
      'Boss: ${_cell(rows, 3, 1)} + ${_cell(rows, 3, 2)}',
      'Staircase: ${_cell(rows, 3, 4)} + ${_cell(rows, 3, 5)}',
    ],
    tables: [
      TableSection(
        title: 'Primary Positions',
        headers: ['Spot', 'Tank', 'Healer'],
        rows: [
          ['Boss', _cell(rows, 3, 1), _cell(rows, 3, 2)],
          ['Boss backups', _cell(rows, 4, 1), _cell(rows, 4, 2)],
        ],
      ),
      TableSection(
        title: 'Staircase',
        headers: ['Spot', 'Tank', 'Healer'],
        rows: [
          ['Staircase', _cell(rows, 3, 4), _cell(rows, 3, 5)],
          ['Stair backups', _cell(rows, 4, 4), _cell(rows, 4, 5)],
          ['Stair portal team', _cell(rows, 5, 4), _cell(rows, 5, 5)],
        ],
      ),
      TableSection(
        title: 'Dispel / Decurse',
        headers: ['Effect', 'Instruction'],
        rows: [
          ['Phase Shifted', _cell(rows, 7, 1)],
          ['Curse of the Rift', _cell(rows, 7, 4)],
        ],
      ),
    ],
    notes: [
      if (_notesFor(notes, 'sanv').isNotEmpty)
        NoteBlock(title: 'Kara notes', items: _notesFor(notes, 'sanv')),
    ],
    imageAsset: 'assets/sanv.png',
    extraImages: const [],
  );
}

BossPlan _buildRupturan(List<List<String>> rows, Map<String, List<String>> notes) {
  return BossPlan(
    name: 'Rupturan',
    description: 'Two-phase encounter with fragments and exile management.',
    highlights: [
      'Phase 1 assigns tanks/healers to boss, exiles, stones',
      'Fragments A/B/C each have tank/healer/soaker',
      'Crumbling Exile handled by casters',
    ],
    tables: [
      TableSection(
        title: 'Phase 1',
        headers: ['Assignment', 'Tank', 'Healer', 'Extra'],
        rows: [
          ['Boss', _cell(rows, 4, 1), _cell(rows, 4, 2), ''],
          [
            'Exiles (x4)',
            _cell(rows, 4, 3),
            _cell(rows, 4, 4),
            _cell(rows, 5, 3).isNotEmpty ? _cell(rows, 5, 3) : _cell(rows, 5, 2)
          ],
          [
            'Living Stone',
            _cell(rows, 4, 7),
            _cell(rows, 4, 8),
            'Soaker: ${_cell(rows, 4, 6)}'
          ],
          [
            'Support team',
            _cell(rows, 4, 15),
            _cell(rows, 5, 15),
            'Puller: ${_cell(rows, 5, 16)}'
          ],
        ],
      ),
      TableSection(
        title: 'Phase 2 - Fragment A',
        headers: ['Role', 'Player'],
        rows: [
          ['Tank', _cell(rows, 8, 1)],
          ['Healer', _cell(rows, 8, 2)],
          ['Soaker', _cell(rows, 8, 3)],
          ['Living Fragment Tank', _cell(rows, 8, 4)],
          ['Living Fragment Healer', _cell(rows, 8, 5)],
          ['DPS', _cell(rows, 8, 6)],
        ],
      ),
      TableSection(
        title: 'Phase 2 - Fragment B',
        headers: ['Role', 'Player'],
        rows: [
          ['Tank', _cell(rows, 11, 1)],
          ['Healer', _cell(rows, 11, 2)],
          ['Soaker', _cell(rows, 11, 3)],
          ['Living Fragment Tank', _cell(rows, 11, 4)],
          ['Living Fragment Healer', _cell(rows, 11, 5)],
          ['DPS', _cell(rows, 11, 6)],
        ],
      ),
      TableSection(
        title: 'Phase 2 - Fragment C',
        headers: ['Role', 'Player'],
        rows: [
          ['Tank', _cell(rows, 14, 1)],
          ['Healer', _cell(rows, 14, 2)],
          ['Soaker', _cell(rows, 14, 3)],
          ['Living Fragment Tank', _cell(rows, 14, 4)],
          ['Living Fragment Healer', _cell(rows, 14, 5)],
          ['DPS', _cell(rows, 14, 6)],
        ],
      ),
      TableSection(
        title: 'Crumbling Exile',
        headers: ['Role', 'Player/Note'],
        rows: [
          ['Tank', _cell(rows, 17, 1)],
          ['Healer', _cell(rows, 17, 2)],
          ['DPS', 'Casters'],
        ],
      ),
    ],
    notes: [
      NoteBlock(
        title: 'Debuffs',
        items: [
          'Felheart/Mana Drain: focus by shadow priests and hunters.',
        ],
      ),
      if (_notesFor(notes, 'rupturan').isNotEmpty)
        NoteBlock(title: 'Kara notes', items: _notesFor(notes, 'rupturan')),
      if (_notesForContains(notes, 'rupturan', 'prep').isNotEmpty)
        NoteBlock(
            title: 'Preparation', items: _notesForContains(notes, 'rupturan', 'prep')),
    ],
    imageAsset: 'assets/rupturan.png',
    extraImages: const ['assets/ruptp1.png', 'assets/ruptp2.png'],
  );
}

BossPlan _buildKruul(List<List<String>> rows, Map<String, List<String>> notes) {
  final healerGroups = TableSection(
    title: 'Healer Groups',
    headers: ['Group', 'Healers'],
    rows: [
      ['Group 1', '${_cell(rows, 2, 1)}, ${_cell(rows, 2, 2)}, ${_cell(rows, 2, 3)}'],
      ['Group 2', '${_cell(rows, 2, 7)}, ${_cell(rows, 2, 8)}, ${_cell(rows, 2, 9)}'],
      ['Group 3', '${_cell(rows, 3, 1)}, ${_cell(rows, 3, 2)}, ${_cell(rows, 3, 3)}'],
      ['Group 4', '${_cell(rows, 3, 7)}, ${_cell(rows, 3, 8)}, ${_cell(rows, 3, 9)}'],
    ],
    caption: 'Healer walls as shown on the sheet.',
  );

  final taunt = TableSection(
    title: 'Taunt Rotation (Phase 2)',
    headers: ['Tank', 'Order'],
    rows: [
      [_cell(rows, 7, 0), _cell(rows, 7, 1)],
      [_cell(rows, 8, 0), _cell(rows, 8, 1)],
      [_cell(rows, 9, 0), _cell(rows, 9, 1)],
      [_cell(rows, 10, 0), _cell(rows, 10, 1)],
    ],
  );

  final magicGrid = TableSection(
    title: 'Group Buff Assignments',
    headers: ['Call', 'Group 1', 'Group 2', 'Group 3', 'Group 4'],
    rows: [
      [
        'Reminder',
        'Dampen Magic (Ranged)',
        'Dampen Magic (Ranged)',
        'Amplify Magic (Melee)',
        'Amplify Magic (Melee)',
      ],
      [
        'Dampen Magic (Ranged)',
        _cell(rows, 12, 11),
        _cell(rows, 12, 12),
        _cell(rows, 12, 13),
        _cell(rows, 12, 14),
      ],
      [
        'Dampen Magic (Ranged 2)',
        _cell(rows, 13, 11),
        _cell(rows, 13, 12),
        _cell(rows, 13, 13),
        _cell(rows, 13, 14),
      ],
      [
        'Amplify Magic',
        _cell(rows, 14, 11),
        _cell(rows, 14, 12),
        _cell(rows, 14, 13),
        _cell(rows, 14, 14),
      ],
      [
        'Melee',
        _cell(rows, 15, 11),
        _cell(rows, 15, 12),
        _cell(rows, 15, 13),
        _cell(rows, 15, 14),
      ],
      [
        'Healers',
        _cell(rows, 16, 11),
        _cell(rows, 16, 12),
        _cell(rows, 16, 13),
        _cell(rows, 16, 14),
      ],
    ],
    caption: 'Healer/class distribution per group from the grid.',
  );

  return BossPlan(
    name: 'Kruul',
    description: 'Taunt rotation, healer grouping, and magic buffs.',
    highlights: [
      'Fire resistance tank: ${_cell(rows, 5, 1)}',
      'Taunt order listed below',
      'Dampen/Amplify Magic split by melee vs ranged',
    ],
    tables: [
      healerGroups,
      TableSection(
        title: 'Support',
        headers: ['Role', 'Player / Note'],
        rows: [
          ['Healer', _cell(rows, 4, 0)],
          ['Fire Res Tank', _cell(rows, 5, 1)],
        ],
      ),
      taunt,
      magicGrid,
    ],
    notes: [
      NoteBlock(
        title: 'Decurse',
        items: [
          _cell(rows, 5, 4).isNotEmpty
              ? _cell(rows, 5, 4)
              : 'Mages/Druids - Skip Paladins on Decursive/Rinse',
        ],
      ),
      if (_notesFor(notes, 'kruul').isNotEmpty)
        NoteBlock(title: 'Kara notes', items: _notesFor(notes, 'kruul')),
    ],
    imageAsset: 'assets/kruul.png',
    extraImages: const [],
  );
}

BossPlan _buildMeph(List<List<String>> rows, Map<String, List<String>> notes) {
  final mainRows = <List<String>>[];
  for (var r = 3; r <= 5 && r < rows.length; r++) {
    mainRows.add([
      _cell(rows, r, 0),
      _cell(rows, r, 1),
      _cell(rows, r, 2),
      _cell(rows, r, 3),
      _cell(rows, r, 4),
      _cell(rows, r, 5),
      _cell(rows, r, 6),
    ]);
  }

  final abilities = <List<String>>[];
  for (var r = 7; r <= 10 && r < rows.length; r++) {
    abilities.add([
      _cell(rows, r, 0),
      _cell(rows, r, 2),
      _cell(rows, r, 4),
      _cell(rows, r, 6),
      _cell(rows, r, 8),
      _cell(rows, r, 9),
    ]);
  }

  // Front shard melee (row 14, columns 4 and 7)
  final front1 = _cell(rows, 14, 4);
  final front2 = _cell(rows, 14, 7);

  // Back shard teams (rows 21-24, columns 3/4 and 7/8)
  final shardRows = <List<String>>[];
  for (var r = 21; r <= 24 && r < rows.length; r++) {
    final leftMain = _cell(rows, r, 3);
    final leftSecond = _cell(rows, r, 4);
    final rightMain = _cell(rows, r, 7);
    final rightSecond = _cell(rows, r, 8);
    if (leftMain.isEmpty &&
        leftSecond.isEmpty &&
        rightMain.isEmpty &&
        rightSecond.isEmpty) {
      continue;
    }
    shardRows.add([
      [leftMain, leftSecond].where((e) => e.isNotEmpty).join(', '),
      [rightMain, rightSecond].where((e) => e.isNotEmpty).join(', '),
    ]);
  }

  return BossPlan(
    name: 'Mephistroth',
    description: 'Assignments for boss, doomguards, crawlers, and shard teams.',
    highlights: [
      'Check shard teams below',
      'Use fear/sleep/vamp priorities from sheet',
    ],
    tables: [
      TableSection(
        title: 'Main Assignments',
        headers: [
          'Boss Tank',
          'Boss Healer',
          'Doomguard Tank',
          'Doomguard Healer',
          'Crawler Tank',
          'Crawler Healer',
          'Crawler DPS'
        ],
        rows: mainRows,
      ),
      TableSection(
        title: 'Ability Priorities',
        headers: [
          'Fear ward',
          'Sleep Paralysis',
          'Vampiric Aura',
          'Carrion Swarm',
          'Melee DPS Prio',
          'Ranged DPS Prio'
        ],
        rows: abilities,
      ),
      TableSection(
        title: 'Shard Teams (Front)',
        headers: ['Front 1', 'Front 2'],
        rows: [
          [front1, front2],
        ],
      ),
      TableSection(
        title: 'Shard Teams (Back)', // visualization via two columns
        headers: ['Back Left', 'Back Right'],
        rows: shardRows.isNotEmpty
            ? shardRows
            : const [
                ['—', '—'],
              ],
      ),
    ],
    notes: [
      if (_notesFor(notes, 'mephistroth').isNotEmpty)
        NoteBlock(title: 'Kara notes', items: _notesFor(notes, 'mephistroth')),
      if (_notesForContains(notes, 'kruul', 'recovery').isNotEmpty)
        NoteBlock(
            title: 'Mephistroth prep',
            items: _notesForContains(notes, 'kruul', 'recovery')),
    ],
    imageAsset: 'assets/mephistroth.png',
    extraImages: const [],
  );
}

BossPlan _buildLeyWatcher(List<List<String>> rows, Map<String, List<String>> notes) {
  final bossRows = <List<String>>[];
  final trapRows = <List<String>>[];
  String _filterLabel(String s) => s.toLowerCase();
  List<String> _filterNotes(List<String> list, List<String> disallow) {
    return list
        .where((n) =>
            !disallow.any((d) => _filterLabel(n).contains(d.toLowerCase())))
        .toSet()
        .toList();
  }
  // rows of interest: header row 2 is labels, 3..5 contain data
  for (var r = 3; r <= 5 && r < rows.length; r++) {
    final tank = _cell(rows, r, 1);
    final healer = _cell(rows, r, 2);
    final backLeft = _cell(rows, r, 4);
    final backRight = _cell(rows, r, 5);
    if (tank.isNotEmpty || healer.isNotEmpty) {
      bossRows.add([tank, healer]);
    }
    if (backLeft.isNotEmpty || backRight.isNotEmpty) {
      trapRows.add([backLeft, backRight]);
    }
  }

  return BossPlan(
    name: 'Ley-Watcher Incantagos',
    description: 'Boss tanks/healers plus hunter traps coverage.',
    highlights: const [
      'Tank/heal assignments and hunter trap positions',
    ],
    tables: [
      TableSection(
        title: 'Boss',
        headers: ['Tank', 'Healer'],
        rows: bossRows,
      ),
      if (trapRows.isNotEmpty)
        TableSection(
          title: 'Hunter Traps',
          headers: ['Back left', 'Back right'],
          rows: trapRows,
        ),
    ],
    notes: [
      if (_notesForContains(notes, 'ley-watcher incantagos', 'prep').isNotEmpty)
        NoteBlock(
            title: 'Preparation',
            items: _notesForContains(notes, 'ley-watcher incantagos', 'prep')),
      if (_notesForContains(notes, 'incantagos', 'recovery').isNotEmpty)
        NoteBlock(
            title: 'Recovery',
            items: _notesForContains(notes, 'incantagos', 'recovery')),
      if (_notesForContains(notes, 'incantagos', 'trash').isNotEmpty)
        NoteBlock(
            title: 'Trash', items: _notesForContains(notes, 'incantagos', 'trash')),
    ],
    imageAsset: 'assets/leywatcher.png',
    extraImages: const [],
  );
}

BossPlan _buildEcho(List<List<String>> rows, Map<String, List<String>> notes) {
  final bossRows = <List<String>>[];
  final kiterRows = <List<String>>[];
  for (var r = 3; r <= 5 && r < rows.length; r++) {
    final tank = _cell(rows, r, 1);
    final healer = _cell(rows, r, 2);
    final kiter = _cell(rows, r, 4);
    if (tank.isNotEmpty || healer.isNotEmpty) {
      bossRows.add([tank, healer]);
    }
    if (kiter.isNotEmpty) {
      kiterRows.add([kiter]);
    }
  }

  final cotRows = <List<String>>[];
  if (rows.length > 7) {
    final assigned = _cell(rows, 7, 0);
    final kicker = _cell(rows, 7, 4);
    if (assigned.isNotEmpty) cotRows.add([assigned]);
    if (kicker.isNotEmpty) cotRows.add(['Kicker: $kicker']);
  }

  return BossPlan(
    name: 'Echo of Medivh',
    description: 'Boss tanks/healers and infernals kiters; CoT kicker duty.',
    highlights: const [
      'Infernal kiters listed with tanks/healers',
      'CoT kicker assignment',
    ],
    tables: [
      TableSection(
        title: 'Boss',
        headers: ['Tank', 'Healer'],
        rows: bossRows,
      ),
      if (kiterRows.isNotEmpty)
        TableSection(
          title: 'Infernals Kiters',
          headers: ['Kiter'],
          rows: kiterRows,
        ),
      if (cotRows.isNotEmpty)
        TableSection(
          title: 'CoT / Kicker',
          headers: ['Assignment'],
          rows: cotRows,
        ),
    ],
    notes: [
      if (_notesFor(notes, 'echo of medivh').isNotEmpty)
        NoteBlock(title: 'Kara notes', items: _notesFor(notes, 'echo of medivh')),
      if (_notesForContains(notes, 'echo of medivh', 'prep').isNotEmpty)
        NoteBlock(
            title: 'Preparation', items: _notesForContains(notes, 'echo of medivh', 'prep')),
    ],
    imageAsset: 'assets/echo.png',
    extraImages: const [],
  );
}

// ignore: unused_element
BossPlan _buildGeneric(String name, List<List<String>> rows, Map<String, List<String>> notes) {
  // Trim empty rows
  final cleaned = rows.where((r) => r.any((c) => c.trim().isNotEmpty)).toList();
  // Drop leading title row if it just contains the tab name
  if (cleaned.isNotEmpty &&
      cleaned.first.where((c) => c.trim().isNotEmpty).length == 1 &&
      cleaned.first.first.toLowerCase() == name.toLowerCase()) {
    cleaned.removeAt(0);
  }

  List<String> headers = [];
  List<List<String>> body = [];
  if (cleaned.isNotEmpty) {
    headers = List<String>.from(cleaned.first);
    // If the first header cell is empty, drop empty leading columns
    while (headers.isNotEmpty && headers.first.trim().isEmpty) {
      headers.removeAt(0);
      for (var i = 0; i < cleaned.length; i++) {
        if (cleaned[i].isNotEmpty) cleaned[i].removeAt(0);
      }
    }
    final maxCols = headers.length;
    body = cleaned.skip(1).map((r) {
      final row = List<String>.filled(maxCols, '');
      for (var i = 0; i < r.length && i < maxCols; i++) {
        row[i] = r[i];
      }
      return row;
    }).toList();
  }

  return BossPlan(
    name: name,
    description: 'Assignments pulled from sheet tab $name.',
    highlights: [
      'Live data from sheet',
      'Tab: $name',
    ],
    tables: [
      TableSection(
        title: name,
        headers: headers,
        rows: body,
      )
    ],
    notes: [
      if (_notesFor(notes, name.toLowerCase()).isNotEmpty)
        NoteBlock(title: 'Kara notes', items: _notesFor(notes, name.toLowerCase())),
    ],
    imageAsset: _assetForGeneric(name),
    extraImages: const [],
  );
}

String _assetForGeneric(String name) {
  final lower = name.toLowerCase();
  if (lower.contains('ley-watcher')) return 'assets/leywatcher.png';
  if (lower.contains('echo')) return 'assets/echo.png';
  return 'assets/anomalus.png';
}
