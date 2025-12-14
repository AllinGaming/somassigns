# Sons of Mukla Assignments

[![GitHub Pages](https://img.shields.io/badge/pages-live-0b8f46)](https://allingaming.github.io/somassigns/)
[![Flutter Web](https://img.shields.io/badge/flutter-web-02569b)](https://flutter.dev)

Flutter web app that pulls raid assignments live from the Google Sheet and presents them per boss with search, personal view, and notes.

## How it works
- **Live sheet ingest:** Each boss tab is fetched from the shared sheet (Gnarlmoon, Ley-Watcher Incantagos, Anomalus, Echo of Medivh, Chess, Sanv, Rupturan, Kruul, Mephistroth).
- **Per-boss layout:** Tables and notes are built per encounter (e.g., Rupturan extra images with zoom, Meph shard teams, Kruul buffs, Ley/Echo prep/recovery).
- **Kara40 notes:** Boss tabs show their Kara notes/prep where relevant; a separate Kara40 notes page lists all notes.
- **Auto-refresh:** Data is reloaded on a timer (sheet remains the single source of truth).

## Using the UI
- **Header controls:** Encounter dropdown with prev/next arrows; toggle search; character avatar/add; “Go to your assignments” link.
- **Search:** Hidden until toggled. Highlights matches; Anomalus shows full table; Gnarlmoon shows side context.
- **Personal assignments:** Save a character (name, class, role). “Go to your assignments” shows your tables/notes, including prep/recovery and role-relevant entries.
- **Images:** Boss portrait per tab; Rupturan phase images tap-to-zoom; Meph shard back/front tables.
