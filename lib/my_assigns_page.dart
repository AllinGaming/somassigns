import 'package:flutter/material.dart';
import 'data.dart';

class MyAssignsPage extends StatefulWidget {
  final List<BossPlan> bosses;
  final String name;
  final String charClass;
  final String role;

  const MyAssignsPage({
    super.key,
    required this.bosses,
    required this.name,
    required this.charClass,
    required this.role,
  });

  @override
  State<MyAssignsPage> createState() => _MyAssignsPageState();
}

class _MyAssignsPageState extends State<MyAssignsPage> {
  bool _showNotes = false;

  @override
  Widget build(BuildContext context) {
    final lower = widget.name.toLowerCase();
    final entries = _collect(lower);
    final visibleEntries =
        _showNotes ? entries : entries.where((e) => !e.notesOnly).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Assignments'),
        backgroundColor: Colors.transparent,
        actions: [
          Row(
            children: [
              const Text('Show notes',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              Checkbox(
                  value: _showNotes,
                  activeColor: const Color(0xFF5C7CFA),
                  onChanged: (v) {
                    setState(() {
                      _showNotes = v ?? true;
                    });
                  }),
              const SizedBox(width: 8),
            ],
          )
        ],
      ),
      body: visibleEntries.isEmpty
          ? const Center(
              child: Text('No assignments found for that name.',
                  style: TextStyle(color: Colors.white70)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visibleEntries.length,
              itemBuilder: (context, index) {
                final e = visibleEntries[index];
                final isLast = index == visibleEntries.length - 1;
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD166),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 3,
                              margin: const EdgeInsets.only(top: 4, bottom: 12),
                              decoration: BoxDecoration(
                                color: isLast ? Colors.transparent : const Color(0xFF2B3041),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Card(
                          elevation: 4,
                          color: const Color(0xFF11151F),
                          margin: const EdgeInsets.only(bottom: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                  color: Color(0xFF30384C), width: 1)),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (e.image != null)
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundImage: AssetImage(e.image!),
                                      ),
                                    if (e.image != null) const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF222735),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(e.boss,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E2533),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(e.section,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 0.2)),
                                    ),
                                    const Spacer(),
                                    if (e.notesOnly && _showNotes)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B2A15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text('Prep',
                                            style: TextStyle(
                                                color: Color(0xFFFFD166),
                                                fontWeight: FontWeight.bold)),
                                      ),
                                  ],
                                ),
                                if (e.detail != null) ...[
                                  const SizedBox(height: 8),
                                  Text(e.detail!,
                                      style: const TextStyle(
                                          color: Colors.white70,
                                          fontStyle: FontStyle.italic)),
                                ],
                                const SizedBox(height: 10),
                                if (e.headers.isNotEmpty)
                                  _tablePreview(e.headers, e.row, lower,
                                      highlightWord: e.reasonHighlight)
                                else if (e.notesOnly && _showNotes)
                                  const Text('No direct assignment; see notes.',
                                      style: TextStyle(color: Colors.white70)),
                                if (_showNotes && e.notes.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ...e.notes.map((n) => Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('• ',
                                                style: TextStyle(
                                                    color: Colors.white70, fontSize: 13)),
                                            Expanded(
                                              child: Text(n,
                                                  style: const TextStyle(
                                                      color: Colors.white70,
                                                      fontSize: 13,
                                                      height: 1.3)),
                                            ),
                                          ],
                                        ),
                                      )),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  String _ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }

  Widget _tablePreview(List<String> headers, List<String> row, String lower,
      {String? highlightWord}) {
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
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF141822)),
          children: [
            for (var i = 0; i < headers.length; i++)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  i < row.length ? row[i] : '',
                  style: TextStyle(
                    color: (i < row.length &&
                            (row[i].toLowerCase().contains(lower) ||
                                (highlightWord != null &&
                                    row[i]
                                        .toLowerCase()
                                        .contains(highlightWord.toLowerCase()))))
                        ? const Color(0xFFFFD166)
                        : Colors.white,
                    fontWeight: (i < row.length &&
                            (row[i].toLowerCase().contains(lower) ||
                                (highlightWord != null &&
                                    row[i]
                                        .toLowerCase()
                                        .contains(highlightWord.toLowerCase()))))
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              )
          ],
        ),
      ],
    );
  }

  List<_AssignEntry> _collect(String lowerName) {
    final list = <_AssignEntry>[];
    final wantMelee = widget.role.toLowerCase().contains('melee');
    final wantRanged = widget.role.toLowerCase().contains('ranged');
    for (final boss in widget.bosses) {
      final isAnomalus = boss.name.toLowerCase() == 'anomalus';
      final anomalusTanks = <String>{};
      final anomalusOrder = <String, String>{};
      if (isAnomalus) {
        for (final section in boss.tables) {
          if (section.title.toLowerCase().contains('tank order')) {
            for (final row in section.rows) {
              for (final cell in row) {
                final trimmed = cell.trim().toLowerCase();
                if (trimmed.isNotEmpty) anomalusTanks.add(trimmed);
              }
              if (row.isNotEmpty) {
                final tank = row[0].trim().toLowerCase();
                final order = row.length > 1 ? row[1].trim() : '';
                if (tank.isNotEmpty && order.isNotEmpty) {
                  anomalusOrder[tank] = order;
                }
              }
            }
          }
        }
        // Fallback: infer order from comma-separated list in Tanks table if tank order table missing.
        if (anomalusOrder.isEmpty) {
          for (final section in boss.tables) {
            if (!section.title.toLowerCase().contains('tank')) continue;
            for (final row in section.rows) {
              for (final cell in row) {
                final parts = cell.split(',');
                for (var i = 0; i < parts.length; i++) {
                  final name = parts[i].trim().toLowerCase();
                  if (name.isEmpty) continue;
                  anomalusTanks.add(name);
                  anomalusOrder[name] = _ordinal(i + 1);
                }
              }
            }
          }
        }
      }

      bool rowMatched = false;
      final addedAnomalusSections = <String>{};
      final addedSectionsForPerson = <String>{}; // boss|section to prevent dup cards
      for (final section in boss.tables) {
        String lastTankName = '';
        final tankCol = section.headers
            .indexWhere((h) => h.toLowerCase().contains('tank'));
        for (final row in section.rows) {
          final isMeaningfulRow =
              row.any((c) => c.trim().isNotEmpty); // skip fully empty rows
          if (!isMeaningfulRow) continue;
          if (tankCol >= 0 && tankCol < row.length && row[tankCol].trim().isNotEmpty) {
            lastTankName = row[tankCol].trim();
          }
          if (row.any((c) => c.toLowerCase().contains(lowerName))) {
            if (isAnomalus &&
                section.title.toLowerCase().contains('healer layout') &&
                anomalusTanks.contains(lowerName)) {
              continue; // skip healer layout for tanks on Anomalus
            }
            if (isAnomalus &&
                section.title.toLowerCase().contains('tank healers') &&
                anomalusTanks.contains(lowerName)) {
              continue; // tanks don't need tank healer table
            }
            if (isAnomalus &&
                section.title.toLowerCase().contains('healer layout') &&
                tankCol >= 0 &&
                tankCol < row.length &&
                row[tankCol].toLowerCase().contains(lowerName)) {
              continue; // if you're listed under Tanks column in healer layout, hide that card
            }
            if (isAnomalus &&
                anomalusTanks.contains(lowerName) &&
                addedAnomalusSections.contains(section.title.toLowerCase())) {
              continue; // avoid duplicate entries across same section for tanks
            }
            final sectionKey = '${boss.name}|${section.title}';
            if (section.title.toLowerCase().contains('tank healer') &&
                addedSectionsForPerson.contains(sectionKey)) {
              continue; // avoid duplicate tank healer cards
            }

            // Surface tank in the row itself when the tank column is empty but already seen in this section.
            var displayRow = row;
            if (tankCol >= 0 &&
                tankCol < row.length &&
                row[tankCol].trim().isEmpty &&
                lastTankName.isNotEmpty) {
              displayRow = List<String>.from(row);
              displayRow[tankCol] = lastTankName;
            }

            String? detail =
                _detailFor(boss.name, section.title, row, lowerName);
            if (isAnomalus && anomalusOrder.containsKey(lowerName)) {
              final ord = anomalusOrder[lowerName]!;
              // Surface order inside the row if we can, otherwise append to detail.
              if (displayRow.length > 1 &&
                  displayRow[0].toLowerCase().contains(lowerName)) {
                displayRow = List<String>.from(displayRow);
                displayRow[1] = ord;
              } else {
                detail = (detail == null || detail.isEmpty)
                    ? 'Tank order: $ord'
                    : '$detail • Tank order: $ord';
              }
            }
            final notes = _notesForBoss(boss);
            // Hide Kruul group buff grid unless mage.
            if (!(boss.name.toLowerCase() == 'kruul' &&
                section.title.toLowerCase().contains('group buff') &&
                widget.charClass.toLowerCase() != 'mage')) {
              list.add(_AssignEntry(
                boss: boss.name,
                section: section.title,
                row: displayRow,
                headers: section.headers,
                detail: detail,
                image: boss.imageAsset,
                notes: notes,
                reasonHighlight: lowerName,
              ));
            }
            rowMatched = true;
            if (isAnomalus && anomalusTanks.contains(lowerName)) {
              addedAnomalusSections.add(section.title.toLowerCase());
            }
            if (section.title.toLowerCase().contains('tank healer')) {
              addedSectionsForPerson.add(sectionKey);
            }
          }
          // If not matched by name but role-based interest (melee/ranged) and section mentions it, include a role card.
          final isKruulBuff = boss.name.toLowerCase() == 'kruul' &&
              section.title.toLowerCase().contains('group buff');
          if (!rowMatched &&
              !isKruulBuff && // don't show group buffs via role-only path
              ((wantMelee &&
                      (section.title.toLowerCase().contains('melee') ||
                          row.any((c) => c.toLowerCase().contains('melee')))) ||
                  (wantRanged &&
                      (section.title.toLowerCase().contains('ranged') ||
                          row.any((c) => c.toLowerCase().contains('ranged')))))) {
            list.add(_AssignEntry(
              boss: boss.name,
              section: '${section.title} (role)',
              row: row,
              headers: section.headers,
              detail: section.title.toLowerCase().contains('melee')
                  ? 'Melee focus'
                  : 'Ranged focus',
              image: boss.imageAsset,
              notes: _notesForBoss(boss),
              reasonHighlight: wantMelee ? 'melee' : 'ranged',
            ));
            rowMatched = true;
          }
        }
      }
      // If no direct assignment row matched but notes are relevant (class/potions), add a notes-only entry.
      if (!rowMatched) {
        final notes = _notesForBoss(boss);
        if (notes.isNotEmpty) {
          list.add(_AssignEntry(
            boss: boss.name,
            section: 'Notes',
            row: const [],
            headers: const [],
            detail: 'Prep / class-related notes',
            image: boss.imageAsset,
            notes: notes,
            notesOnly: true,
          ));
        }
      }
    }
    return list;
  }

  String? _detailFor(String boss, String section, List<String> row, String lowerName) {
    final secLower = section.toLowerCase();
    if (boss.toLowerCase() == 'gnarlmoon') {
      if (secLower.contains('left')) return 'Left side';
      if (secLower.contains('right')) return 'Right side';
      if (secLower.contains('tanks')) {
        final leftMatch = row.isNotEmpty && row[0].toLowerCase().contains(lowerName);
        final rightMatch = row.length > 1 && row[1].toLowerCase().contains(lowerName);
        if (leftMatch) return 'Left Tank';
        if (rightMatch) return 'Right Tank';
      }
    }
    return null;
  }

  List<String> _notesForBoss(BossPlan boss) {
    final collected = <String>[];
    final seen = <String>{};
    for (final note in boss.notes) {
      for (final item in note.items) {
        if (seen.add(item)) collected.add(item);
      }
    }
    return collected;
  }
}

class _AssignEntry {
  final String boss;
  final String section;
  final List<String> row;
  final List<String> headers;
  final String? detail;
  final String? image;
  final List<String> notes;
  final bool notesOnly;
  final String? reasonHighlight;

  _AssignEntry({
    required this.boss,
    required this.section,
    required this.row,
    required this.headers,
    this.detail,
    this.image,
    required this.notes,
    this.notesOnly = false,
    this.reasonHighlight,
  });
}
