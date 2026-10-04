# 🎮 Limezu Sprite Hub & Studio

An intuitive web dashboard to view, search, slice, and create sprites from Limezu asset packs in one place.

## ✨ Features

- **55,000+ Sprites Indexed**: Automatically indexes Modern Office, Modern Interiors, Modern UI, and zip archives directly on macOS with zero decompression delays.
- **Instant Search & Filtering**: Real-time filtering by folder, keywords (chair, desk, alex, hair, etc.), resolution (`16×16`, `32×32`, `48×48`), and type (singles, sheets, animations).
- **📋 One-Click Copy**: Copy raw PNG data directly to macOS clipboard with one click (`Cmd+V` into Photoshop, Aseprite, game engines).
- **✂️ Interactive Sprite Sheet Slicer**: Open any sheet or tileset, overlay a snap grid (`16×16`, `32×32`, `48×48`), drag-select regions, and extract or copy slices.
- **🎨 Item Studio & Sprite Maker**: Layered canvas compositor to build new items, transform layers (flip, rotate, move), draw/erase pixel art, and save directly to `My_Custom_Items`.
- **Zero Dependencies**: Built entirely with Python's standard library (`http.server`, `zipfile`, `json`). No `pip install` required.

## 🚀 How to Run

Double-click `Limezu Sprite Hub.command` on your Desktop, or run:

```bash
./run_dashboard.sh
```

Then open [http://localhost:5050](http://localhost:5050) in your web browser.
