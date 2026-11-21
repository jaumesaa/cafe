# ☕️ cafe

> **Keep your Mac awake in style.**  
> Crafted by [mainlab.es](https://mainlab.es) · [App Store de mainlab.es](https://mainlab.es)

A native, lightweight macOS utility designed for MacBooks that prevents sleep with an elegant fluid cup visualization right in your menu bar. Open it from Spotlight, choose your duration, and click **Keep Awake**.

Powered by native `caffeinate -dims` — keeps your display, idle state, and disk awake while compiling, rendering, or watching presentations.

Requires macOS 26 or later.

---

## 🚀 Features

- **Liquid Glass Interface:** Designed natively with modern macOS design principles.
- **Dynamic Menu Bar Visualizer:** A detailed coffee cup appears in your menu bar while active and gradually empties as time elapses.
- **Fluid Steam Effect:** Subtle rising steam while the coffee is fresh (>75% remaining or infinite session).
- **Flexible Timer:** Dial in hours and minutes, or leave at 0:00 for an unlimited keep-awake session.
- **Zero Background Overhead:** Leaves no permanent background daemons or login items; cleanly dismisses when idle or finished.
- **Universal Binary:** Optimized for both Apple Silicon (M1/M2/M3/M4) and Intel MacBooks.
- **Light on the battery:** the menu-bar cup only redraws when it changes, and the steam pauses while the display sleeps.

---

## 📥 Install

### Option A: Download
Cafe comes with every AnyAction license, and is sold on its own at [anyaction.app/cafe](https://anyaction.app/cafe).
1. Open **Cafe.dmg** (signed and notarized by Apple).
2. Drag **cafe** to your Applications folder.
3. Open it from Spotlight.

### Option B: Build from source

```bash
git clone https://github.com/YOUR_USER/Cafe.git
cd Cafe
chmod +x Scripts/install.sh
./Scripts/install.sh
```

---

## 📦 Release

`Scripts/release-dmg.sh` builds the signed, notarized **Cafe.dmg** (`--dry-run` to try the layout without notarizing).

---

## 💡 How to Use

1. Launch **cafe** via Spotlight or from Applications.
2. Adjust **Hours** and **Minutes** using the custom glass sliders (or leave at 0 for unlimited).
3. Click **Keep Awake**.
4. The window will gracefully minimize to the menu bar with a warm ambient bloom.
5. Click the cup icon in your menu bar at any time to check remaining time or press **Stop**.

---

## 🌐 Credits & Links

- **Created by:** [mainlab.es](https://mainlab.es)
- **Author:** Jaume Sampol Alcover
- **Website:** [https://mainlab.es](https://mainlab.es)

---

## 📄 License

MIT © 2026 Jaume Sampol Alcover · mainlab.es

