# HomeButler Development Guide

HomeButler is a Home Assistant control app for jailbroken iOS devices (targets iOS 9.3.5).

## Build Systems

This project uses **two build systems** that must be kept in sync:

1. **Theos** - Primary build for deployment to jailbroken devices
2. **Xcode** - For code editing, IDE features, and simulator testing

When adding new files, update BOTH:
- `Makefile` - Add `.m` files to `HomeButler_FILES`
- `HomeButler.xcodeproj/project.pbxproj` - Add file references and build phases

## Deploying to Device

### Prerequisites

- [Theos](https://theos.dev/docs/installation) installed
- Jailbroken iOS device with SSH enabled
- `sshpass` installed (`brew install hudochenkov/sshpass/sshpass`)

### Deploy

```bash
# Set your device IP and run
IPAD_IP=192.168.1.xxx ./deploy.sh
```

Or edit `deploy.sh` and set `IPAD_IP` directly.

### SSH Access

```bash
ssh root@<DEVICE_IP>
# Default password: alpine
```

### Viewing Logs

```bash
ssh root@<DEVICE_IP>
tail -f /var/log/syslog | grep HomeButler
```

Crash logs:
```bash
ls -la /var/mobile/Library/Logs/CrashReporter/
cat /var/mobile/Library/Logs/CrashReporter/HomeButler-*.ips
```

## Building

### Theos (for deployment)
```bash
make clean && make package FINALPACKAGE=1
```

Output: `packages/com.homebutler.app_X.X.X_iphoneos-arm.deb`

### IPA (for distribution)
```bash
./build_ipa.sh
```

Output: `HomeButler.ipa`

## Architecture

### UI Layout
- **Standard Spacing**: 12.0 points throughout the app
- **Entity Cards**: Tap to toggle, vertical drag for brightness (dimmable lights)
- **Tap Feedback**: 6px golden border animation (100ms fade in/out)

### Orientation-Aware Layouts

The app uses different layouts for landscape and portrait. Orientation is detected using `isPortraitOrientation` which compares `contentView.bounds` width vs height.

**Home Screen - Landscape:**
- Left 50%: Weather (current top, 6-day forecast bottom in 2x3 grid)
- Right 50%: Entity cards in 2-column grid

**Home Screen - Portrait:**
- Top: Entity cards in 4-column grid
- Bottom: Weather section

### Supported Entity Types

| Type | Behavior |
|------|----------|
| `light.*` | Toggle on/off, brightness slider (if supported) |
| `switch.*` | Toggle on/off |
| `sensor.*` | Display only (read-only) |
| `binary_sensor.*` | Display only (read-only) |
| `script.*` | Tap to trigger (play icon) |
| `input_boolean.*` | Toggle on/off |

### Drag-Drop Reordering

Entity cards on the Home screen support drag-to-reorder:

1. **Long-press** (0.5s) lifts a card
2. **Drag**: Dashed placeholder shows drop position
3. **Release**: Order persists to UserDefaults

Key methods:
- `handleHomeSensorLongPress:` - Gesture handler
- `createDropPlaceholderWithFrame:` - Visual feedback
- `updateDropPlaceholderToIndex:` - Position updates

## Key Files

| File | Purpose |
|------|---------|
| `AppDelegate.m` | Entry point, loads HBDashboardViewController |
| `HBDashboardViewController.h/m` | Main dashboard (Home/Rooms tabs, weather, entities) |
| `HBRoom.h/m` | Room model + HBRoomManager singleton |
| `HBRoomDetailViewController.h/m` | Individual room view |
| `HBLightToggleCell.h/m` | Entity card (tap-toggle, brightness drag) |
| `HBThemeManager.h/m` | Centralized theming |
| `HAAPIClient.h/m` | Home Assistant REST API client |
| `HAEntity.h/m` | Entity model |

## API Integration

Uses Home Assistant REST API:

```
GET  /api/states                           # Fetch all entities
POST /api/services/{domain}/{service}      # Call services
POST /api/services/weather/get_forecasts   # Weather forecast
GET  /api/camera_proxy/{entity_id}         # Camera stream
```

All requests use Bearer token authentication.

## Theming

Colors defined in `HBThemeManager`:
- `backgroundColor` - Main background
- `cardBackgroundColor` - Entity cards
- `textColor` / `secondaryTextColor` - Text
- `onColor` - Active state (golden yellow)
- `offColor` - Inactive state

## Modal Presentation

All modals use `UIModalPresentationFullScreen` for consistent appearance across iOS versions.
