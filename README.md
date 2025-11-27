# HomeButler

A native iOS app for controlling Home Assistant, designed for jailbroken devices running iOS 9.3.5+.

![iOS 9.3.5+](https://img.shields.io/badge/iOS-9.3.5+-blue)
![Objective-C](https://img.shields.io/badge/language-Objective--C-orange)
![Home Assistant](https://img.shields.io/badge/Home%20Assistant-REST%20API-41BDF5)

## Features

- **Dashboard**: Home tab with weather and customizable entity cards
- **Rooms**: Organize entities into rooms with custom names
- **Weather**: Current conditions and 6-day forecast display
- **Light Control**: Toggle on/off, adjust brightness with vertical drag
- **Scripts**: Tap-to-trigger support for Home Assistant scripts
- **Sensors**: Display sensor values with units
- **Drag & Drop**: Reorder entities on the home screen
- **Dark Theme**: Native dark UI optimized for always-on displays

## Screenshots

*Coming soon*

## Requirements

- Jailbroken iOS device (iOS 9.3.5+)
- [Theos](https://theos.dev/docs/installation) build system
- Home Assistant instance with REST API access
- Long-lived access token from Home Assistant

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/HomeButler.git
   cd HomeButler
   ```

2. Build with Theos:
   ```bash
   make clean && make package FINALPACKAGE=1
   ```

3. Deploy to device:
   ```bash
   IPAD_IP=192.168.1.xxx ./deploy.sh
   ```

### Getting a Home Assistant Token

1. Open Home Assistant web interface
2. Click your profile (bottom left)
3. Scroll to "Long-Lived Access Tokens"
4. Click "Create Token"
5. Copy the token (you'll need this in the app)

## Usage

### First Launch

1. Enter your Home Assistant URL (e.g., `http://192.168.1.100:8123`)
2. Enter your long-lived access token
3. Tap "Test Connection" to verify
4. Tap "Save & Continue"

### Home Tab

- View weather and selected entity cards
- Tap the pencil icon to add/remove entities
- Long-press and drag to reorder cards
- Tap "All On" / "All Off" to control all lights

### Rooms Tab

- Tap "+" to create a new room
- Select a room to view its entities
- Tap "Edit" to modify room settings

### Controlling Entities

| Entity Type | Interaction |
|-------------|-------------|
| Lights | Tap to toggle, drag vertically for brightness |
| Switches | Tap to toggle |
| Scripts | Tap to trigger |
| Sensors | Display only |

## Project Structure

```
HomeButler/
├── API/
│   └── HAAPIClient.h/m       # Home Assistant REST API client
├── Models/
│   ├── HAEntity.h/m          # Entity data model
│   └── HBRoom.h/m            # Room model & persistence
├── ViewControllers/
│   ├── HBDashboardViewController  # Main dashboard
│   ├── HBRoomDetailViewController # Room view
│   ├── HBAddRoomViewController    # Room editor
│   └── SettingsViewController     # Configuration
├── Views/
│   └── HBLightToggleCell.h/m # Entity card cell
├── Theme/
│   └── HBThemeManager.h/m    # Centralized theming
└── Supporting Files/
    ├── Info.plist
    └── Makefile              # Theos build config
```

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development documentation including:
- Build system setup
- Architecture overview
- Key files and methods
- Deployment instructions

## API Integration

The app uses Home Assistant's REST API:

| Endpoint | Purpose |
|----------|---------|
| `GET /api/states` | Fetch all entities |
| `POST /api/services/{domain}/{service}` | Control entities |
| `POST /api/services/weather/get_forecasts` | Weather data |

## Security Notes

- Access tokens are stored in UserDefaults
- `NSAllowsArbitraryLoads` is enabled for local HTTP connections
- For remote access, use HTTPS with a reverse proxy

## Troubleshooting

**Connection fails:**
- Verify Home Assistant URL is reachable from your device
- Check that the access token is valid
- Try using IP address instead of hostname

**Entities don't appear:**
- Pull to refresh the dashboard
- Verify Home Assistant is running
- Check entity types are supported

## License

MIT License - See [LICENSE](LICENSE) for details.

## Acknowledgments

- Built for the Home Assistant community
- Designed for legacy iOS devices that deserve smart home control
