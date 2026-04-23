# GardenEar 🌿

> Identify birds and backyard wildlife by sound — tap, record, discover.

GardenEar is a native iOS app that records ambient audio and uses AI to identify the species present. Results are saved to a personal journal, pinned on a map, and tracked as a monthly biodiversity score. The app works fully offline once the on-device BirdNET model is downloaded.

---

## Screenshots

| Record | Journal | Map |
|--------|---------|-----|
| ![Record](https://raw.githubusercontent.com/sridharippili/GardenEar/main/Screenshots/gardenear_01_record_idle.png) | ![Journal](https://raw.githubusercontent.com/sridharippili/GardenEar/main/Screenshots/gardenear_03_journal.png) | ![Map](https://raw.githubusercontent.com/sridharippili/GardenEar/main/Screenshots/gardenear_04_map.png) |

| Score | Sighting Detail | Field Notes Card |
|-------|----------------|-----------------|
| ![Score](https://raw.githubusercontent.com/sridharippili/GardenEar/main/Screenshots/gardenear_05_score.png) | ![Detail](https://raw.githubusercontent.com/sridharippili/GardenEar/main/Screenshots/gardenear_07_sighting_detail.png) | ![Card](https://raw.githubusercontent.com/sridharippili/GardenEar/main/Screenshots/gardenear_08_shareable_card.png) |

---

## Features

### 🎙️ Record & Identify
- One-tap audio recording with a live **sonic waveform** visualiser
- MM:SS timer and animated ping rings during recording
- Upload any existing audio file for analysis
- Confidence score returned for each detected species

### 🤖 AI Identification Providers
| Provider | When used | Notes |
|----------|-----------|-------|
| **NatureLM-audio** | Online (default) | Routed via Kaggle/Colab backend |
| **BirdNET** (server) | Online fallback | Cornell Lab · 6,000+ species |
| **BirdNET TFLite** | Offline | Download once (~50 MB), runs on-device |

### 📓 Journal
- Every confirmed sighting is saved with species name, scientific name, life stage, call type, confidence, GPS coordinates, and timestamp
- Grouped by date with a live count of total sightings and unique species
- Swipe to delete any entry

### 🗺️ Map
- All geo-tagged sightings plotted as custom pins
- Auto-centres and fits all pins on first load
- **Grid-based clustering** (5×5) when > 20 sightings are zoomed out
- Tap a cluster to zoom in; tap a pin to see a quick-info card
- ± zoom controls with clamped min/max span

### 📊 Score
- Monthly biodiversity score — count of unique species identified
- Personal best tracker across all months
- 6-month bar chart history

### ⚙️ Settings
- Device storage indicator
- Download / delete the on-device **BirdNET TFLite** model
- Live connection status (online → BirdNET server, offline → local model)
- NatureLM-audio card (coming soon)

### 🃏 Shareable Field Notes Card
- Tap the share icon on any sighting to export a **375 × 600 pt** premium card
- Dark forest-green design with cream text and gold/teal accent lines
- Includes: species name (serif bold), scientific name (italic), 40-bar waveform, map snapshot with pin, confidence %, provider, reverse-geocoded location
- Rendered via `ImageRenderer` at 3× scale for crisp Instagram-story quality

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI (iOS 16+) |
| Audio recording | AVFoundation (`AVAudioRecorder`) |
| On-device inference | TensorFlowLiteSwift 2.14 (CocoaPods) |
| Local database | SQLite.swift 0.15.3 (Swift Package Manager) |
| Map | MapKit (`Map`, `MKMapSnapshotter`, `MKMapSnapshotter`) |
| Location | CoreLocation (`CLGeocoder` reverse geocoding) |
| Networking | `URLSession` async/await |
| Connectivity | `Network` framework (`NWPathMonitor`) |
| Card export | `ImageRenderer` (iOS 16+) |
| Project generation | xcodegen |
| Dependency management | CocoaPods + Swift Package Manager |

---

## Project Structure

```
GardenEar/
├── App/
│   ├── GardenEarApp.swift        # App entry point, tab bar setup
│   ├── Theme.swift               # Colour palette, typography
│   └── AppIconGenerator.swift
├── Components/
│   ├── WaveformView.swift        # 60-line × 80-segment Canvas waveform
│   ├── ShareableFieldNotesCard.swift  # ImageRenderer export card
│   ├── ResultCard.swift          # Species detection result list
│   ├── SightingRow.swift         # Journal list row
│   ├── SightingMapPin.swift      # Custom map annotation view
│   ├── SightingMapCard.swift     # Map bottom-sheet card
│   ├── SpeciesRow.swift          # Confidence pill + species info
│   ├── MonthlyBarChart.swift     # Score bar chart
│   ├── ModelDownloadCard.swift   # BirdNET download UI
│   └── LifeStageBadge.swift
├── Screens/
│   ├── RecordScreen/             # RecordView + RecordViewModel
│   ├── JournalScreen/            # JournalView, SightingDetailView, ViewModels
│   ├── MapScreen/                # MapView + MapViewModel (clustering)
│   ├── ScoreScreen/              # ScoreView + ScoreViewModel
│   └── SettingsScreen/           # SettingsView
├── Services/
│   ├── AudioIdentificationService.swift   # Provider selection logic
│   ├── Providers/
│   │   ├── BirdNETProvider.swift          # Online BirdNET API
│   │   ├── BirdNETLocalProvider.swift     # On-device TFLite inference
│   │   ├── NatureLMProvider.swift         # NatureLM-audio router
│   │   └── BirdSoundClassifierProvider.swift
│   ├── LocationService.swift
│   ├── NetworkMonitor.swift       # NWPathMonitor with sync initial state
│   ├── OfflineModelManager.swift  # BirdNET download + state machine
│   └── NatureLMService.swift
├── Database/
│   └── DatabaseManager.swift     # SQLite.swift CRUD for sightings
├── Models/
│   ├── Sighting.swift
│   └── MonthlyScore.swift
└── Resources/
    ├── Info.plist
    └── Assets.xcassets
```

---

## Requirements

- **Xcode 15+**
- **iOS 16.0+** deployment target
- **CocoaPods** — for TensorFlowLiteSwift
- **xcodegen** — to regenerate the `.xcodeproj` from `project.yml`

---

## Getting Started

```bash
# 1. Clone
git clone https://github.com/sridharippili/GardenEar.git
cd GardenEar

# 2. Regenerate the Xcode project
xcodegen generate

# 3. Install CocoaPods dependencies
LANG=en_US.UTF-8 pod install

# 4. Open the workspace (NOT the .xcodeproj)
open GardenEar.xcworkspace
```

> ⚠️ Always open **`GardenEar.xcworkspace`** — opening `.xcodeproj` directly will break TensorFlowLite imports.

Select the **iPhone simulator or a physical device** and press **Run (⌘R)**.

---

## Offline Mode

1. Open the **Settings** tab in the app
2. Tap **Download BirdNET — 50 MB**
3. Once downloaded, the app identifies species entirely on-device with no internet connection

The local model file (`BirdNET_GLOBAL_6K_V2.4.tflite`) and labels file (`BirdNET_GLOBAL_6K_V2.4_Labels.txt`) must be added to the Xcode project target for on-device inference to activate.

---

## Backend (NatureLM)

The online provider routes audio to a self-hosted NatureLM-audio inference server:

```
POST https://gardenear-router.onrender.com/identify
     ?query=What+is+the+common+name+of+the+bird+species+in+this+audio%3F+Answer%3A
Content-Type: multipart/form-data
Body: audio file
```

The router forwards requests to a Kaggle or Colab notebook running the NatureLM-audio model. Start the notebook before using the online mode.

---

## Contributing

Pull requests are welcome. For major changes please open an issue first.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes
4. Push and open a Pull Request

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

*Built with SwiftUI · Powered by BirdNET (Cornell Lab of Ornithology) and NatureLM-audio (Earth Species Project)*
