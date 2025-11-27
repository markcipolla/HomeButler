# Home Butler - Setup Guide

## Quick Start for iOS 9.3.5

This guide will help you get Home Butler running on your iOS 9.3.5 device.

## Prerequisites

1. **Mac with Xcode 7.3+** (Required for iOS 9.3.5 development)
2. **Home Assistant Instance** running and accessible on your network
3. **iOS Device** running iOS 9.3.5 or later

## Step 1: Prepare Home Assistant

### Create a Long-Lived Access Token

1. Open Home Assistant in your web browser
2. Click your profile icon in the bottom left
3. Scroll to "Long-Lived Access Tokens" section
4. Click "Create Token"
5. Name it "HomeButler" or similar
6. **IMPORTANT**: Copy the token immediately - you won't be able to see it again!

### Note Your Home Assistant URL

Your URL will typically be one of:
- `http://homeassistant.local:8123` (if using mDNS)
- `http://192.168.1.XXX:8123` (replace XXX with your Home Assistant's IP)
- Your external URL if accessing remotely

**Tip**: Use the IP address format for most reliable connection on iOS 9.3.5

## Step 2: Build the App

### Option A: Using Xcode GUI

1. Open Xcode 7.3 or later
2. Open `HomeButler.xcodeproj`
3. Connect your iOS 9.3.5 device via USB
4. Select your device from the device dropdown
5. Click the Play button (or Cmd+R)

### Option B: Using Command Line

```bash
# Navigate to project directory
cd path/to/HomeButler

# Build for device (requires code signing)
xcodebuild -project HomeButler.xcodeproj -scheme HomeButler -configuration Debug

# Build for simulator
xcodebuild -project HomeButler.xcodeproj -scheme HomeButler -configuration Debug -sdk iphonesimulator
```

## Step 3: Configure the App

### First Launch

1. The app will show the Settings screen
2. Enter your Home Assistant URL
   - Example: `http://192.168.1.100:8123`
   - Do NOT include a trailing slash
3. Paste your long-lived access token
4. Tap "Test Connection"
   - This verifies the app can reach your Home Assistant
   - You should see "Success! Found X entities"
5. Tap "Save & Continue"

### Troubleshooting Connection Issues

**"Connection failed" error:**
- Verify your iOS device is on the same network as Home Assistant
- Ping the Home Assistant IP from your computer to verify it's reachable
- Try using the IP address instead of hostname
- Check that port 8123 is not blocked by firewall

**"HTTP 401" error:**
- Your access token is invalid or expired
- Create a new token in Home Assistant
- Make sure you copied the entire token

**"HTTP 403" error:**
- Your token doesn't have sufficient permissions
- Recreate the token in Home Assistant

## Step 4: Using the App

### Dashboard

The dashboard shows all your entities with these filters:
- **All**: Every entity Home Assistant knows about
- **Lights**: Only light entities
- **Switches**: Only switch entities
- **Sensors**: Only sensor entities
- **Cameras**: Only camera entities

**Pull down** to refresh the entity list.

### Controlling Lights

1. Tap any light in the dashboard
2. Use the **Power** switch to turn on/off
3. Adjust **Brightness** slider (if supported)
   - Changes apply automatically after 0.5 seconds
4. Change **RGB Color** (if supported)
   - Adjust R, G, B sliders
   - Tap "Apply Color" to send changes

### Controlling Switches

Simply tap any switch in the dashboard to toggle it.

### Viewing Sensors

Tap any sensor to see:
- Current state
- All attributes (temperature, humidity, etc.)

### Viewing Cameras

1. Tap any camera entity
2. Stream refreshes every second
3. Tap back to return to dashboard (stops streaming)

## Step 5: Managing Settings

To change your Home Assistant URL or token:

1. Tap **Settings** in the top-right of the dashboard
2. Update URL or token
3. Tap "Test Connection" to verify
4. Tap "Save & Continue"

## iOS 9.3.5 Specific Notes

### Why iOS 9.3.5?

This version was specifically requested and is compatible with:
- iPhone 4S
- iPad 2, iPad 3, iPad Mini (1st gen)
- iPod Touch 5th gen

### Limitations

- Uses older Objective-C syntax compatible with Xcode 7.3
- No Swift support for iOS 9.3.5 compatibility
- Uses NSURLSession (not newer URLSession)
- Manual UI layout (no SwiftUI)

### Security Note

The app has `NSAllowsArbitraryLoads` enabled in Info.plist because:
- Most local Home Assistant instances use HTTP, not HTTPS
- iOS 9 requires this setting to connect to non-HTTPS servers
- This is safe for local network use

**WARNING**: If accessing Home Assistant over the internet, use HTTPS!

## Advanced: Xcode Project Settings

If you need to modify code signing or deployment target:

1. Open project in Xcode
2. Select "HomeButler" project in navigator
3. Select "HomeButler" target
4. **General** tab:
   - Deployment Target: iOS 9.3
   - Bundle Identifier: com.homebutler.HomeButler
5. **Signing & Capabilities** tab:
   - Select your development team
   - Xcode will auto-generate provisioning profile

## Common Issues

### App crashes on launch
- Check Xcode console for errors
- Verify deployment target is set to iOS 9.3
- Clean build folder (Product → Clean Build Folder)

### Entities don't appear
- Pull to refresh the dashboard
- Check Settings are correct
- Verify Home Assistant is running
- Check Home Assistant logs for API errors

### Camera won't load
- Ensure camera entity exists in Home Assistant
- Check camera is accessible via `/api/camera_proxy/camera.entity_id`
- Some camera types may not be compatible

### Light controls don't work
- Verify the light supports the feature (brightness, color)
- Check Home Assistant entity attributes
- Try controlling from Home Assistant web UI first

## File Structure Reference

```
HomeButler/
├── HomeButler.xcodeproj/       # Xcode project file
├── HomeButler/                 # Source code
│   ├── API/                    # Home Assistant API client
│   ├── Models/                 # Data models
│   ├── ViewControllers/        # UI controllers
│   ├── Views/                  # Custom views
│   ├── Resources/              # Storyboards, assets
│   └── Supporting Files/       # Info.plist, main.m
├── README.md                   # Project documentation
└── SETUP_GUIDE.md             # This file
```

## Getting Help

If you encounter issues:

1. Check Home Assistant is accessible from your device's browser
2. Verify your access token is valid
3. Review Xcode console for error messages
4. Check Home Assistant logs for API errors
5. Try recreating your access token

## Next Steps

Consider enhancing the app with:
- Custom entity grouping
- Widget support (iOS 10+)
- Scene activation
- Automation triggers
- Climate control
- Media player controls

Happy home automating! 🏠
