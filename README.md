# Sons of Mukla - Assignments

A lightweight Flutter web app that renders raid assignments pulled live from the shared Google Sheet.

## Features
- **Boss selector:** Switch between Gnarlmoon, Anomalus, Chess, Sanv, Rupturan, Kruul, and Mephistroth.
- **Live data:** Reads directly from the sheet (no rebuild needed when the sheet updates).
- **Tables:** Clean, dark-themed layouts sized for web; class/role tables stay readable without horizontal scroll.
- **Search:** Find your name across all encounters.
  - Anomalus and other bosses show full tables with your name highlighted.
  - Gnarlmoon search includes side context (Left/Right tank, etc.).
- **Visuals:** Per-boss profile art plus extra images for Rupturan with tap-to-zoom fullscreen view.
- **Notes:** Boss-specific Kara40 notes rendered prominently for quick callouts.

## Usage Tips
- Use the dropdown to change encounters; search clears automatically on change.
- Use the search box to highlight every assignment you’re on; a clear button appears when you type.
- Tap Rupturan phase images to open a fullscreen zoom viewer.
