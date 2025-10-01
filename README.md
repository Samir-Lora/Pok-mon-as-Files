# Pokemon - macOS File Provider Extension

A macOS application that displays Pokemon from the PokeAPI as files in Finder using a File Provider Extension.

## Overview

This application creates a virtual file system that shows the first 151 Pokemon from the PokeAPI as `.txt` files in Finder. The app runs in the background as a menu bar utility with options to connect/disconnect the file provider domain and refresh the Pokemon data.

## Features

- **Menu Bar App**: No main window, operates entirely from the system menu bar
- **File Provider Extension**: Creates a virtual "Pokemon Drive" visible in Finder
- **PokeAPI Integration**: Fetches the first 151 Pokemon from https://pokeapi.co/api/v2/pokemon?limit=151
- **Caching**: Stores Pokemon data using App Groups for offline access
- **Real-time Status**: Visual status indicator and detailed popover view

## Architecture

### Components

1. **Main App (`Pokemon.app`)**
   - Menu bar interface with status indicator
   - Domain management (connect/disconnect/refresh)
   - Status popover with connection details

2. **File Provider Extension (`PokemonFileProviderExtension`)**
   - NSFileProviderReplicatedExtension implementation
   - Virtual folder structure: Root > Pokemon > [pokemon files]
   - Enumeration of Pokemon as text files

3. **Shared Components**
   - `PokemonModels.swift`: Data models for API responses and file items
   - `PokeAPIService.swift`: Network service for fetching Pokemon data
   - `FileProviderDomainManager.swift`: Domain lifecycle management

## Project Structure

```
Pokemon/
├── Pokemon/                    # Main app target
│   ├── AppDelegate.swift                # Menu bar app setup
│   ├── StatusViewController.swift       # Popover status view
│   ├── Shared/                         # Shared code between app and extension
│   │   ├── PokemonModels.swift         # Data models
│   │   ├── PokeAPIService.swift        # API service
│   │   └── FileProviderDomainManager.swift # Domain management
│   ├── Info.plist                     # App configuration
│   └── Pokemon.entitlements     # App sandbox permissions
├── PokemonFileProviderExtension/        # File Provider Extension target
│   ├── FileProviderExtension.swift     # Main extension class
│   ├── PokemonEnumerators.swift        # File system enumerators
│   ├── Info.plist                     # Extension configuration
│   └── PokemonFileProviderExtension.entitlements # Extension permissions
└── README.md                           # This file
```

## Requirements

- **macOS**: 13.0+ (Ventura)
- **Xcode**: 14.0+
- **Swift**: 5.7+
- **Developer Account**: Required for App Groups and File Provider capabilities

## Build Instructions

### 1. Prerequisites

1. Open the project in Xcode
2. Ensure you have a valid Apple Developer account
3. Update the Team ID in project settings

### 2. IMPORTANT: Manual Project Setup Required

⚠️ **Note**: The project files have been created programmatically and need to be properly integrated into Xcode. Follow these critical steps:

#### A. Add File Provider Extension Target

1. In Xcode, go to **File** > **New** > **Target**
2. Choose **macOS** > **File Provider Extension**
3. Product Name: `PokemonFileProviderExtension`
4. Embed in Application: `Pokemon`
5. **IMPORTANT**: Delete the auto-generated extension files
6. Add our custom extension files to the target:
   - `PokemonFileProviderExtension/FileProviderExtension.swift`
   - `PokemonFileProviderExtension/PokemonEnumerators.swift`
   - `PokemonFileProviderExtension/Info.plist`
   - `PokemonFileProviderExtension/PokemonFileProviderExtension.entitlements`

#### B. Add Files to Main Target

1. Right-click on the main `Pokemon` group in Xcode
2. Choose **Add Files to "Pokemon"**
3. Add these files to the main app target:
   - `AppDelegate.swift`
   - `StatusViewController.swift`
   - `Info.plist` (main app)
   - `Pokemon.entitlements`

#### C. Add Shared Files to Both Targets

1. Add the `Shared/` folder files to **both** targets:
   - `Shared/PokemonModels.swift`
   - `Shared/PokeAPIService.swift`
   - `Shared/FileProviderDomainManager.swift`
2. Ensure Target Membership is checked for both apps

### 3. Configure Code Signing

1. Select the project in Xcode
2. Update **Development Team** for both targets:
   - `Pokemon` (main app)
   - `PokemonFileProviderExtension`

### 4. Configure App Groups

The project uses App Groups to share data between the main app and extension:

1. In Apple Developer Portal, create an App Group:
   - Identifier: `group.lb.pokemon`
   - Description: "Pokemon Data Sharing"

2. Enable App Groups capability for both app identifiers:
   - Main app: `lb.Pokemon`
   - Extension: `lb.Pokemon.PokemonFileProviderExtension`

### 4. Build the Project

```bash
# Clean build folder
xcodebuild clean -project "Pokemon.xcodeproj"

# Build both targets
xcodebuild -project "Pokemon.xcodeproj" -scheme "Pokemon" -configuration Debug build
```

### 5. Code Signing & Notarization (Optional)

For distribution outside of development:

```bash
# Sign the app
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" "Pokemon.app"

# Notarize (requires Apple Developer Program)
xcrun notarytool submit "Pokemon.app" --keychain-profile "YourProfile" --wait
```

## Installation & Testing

### 1. Install the App

1. Build the project in Xcode
2. Locate `Pokemon.app` in the build output
3. Copy to `/Applications` folder
4. Launch the app

### 2. Register the File Provider Extension

The File Provider Extension must be registered with the system:

```bash
# Check if extension is loaded
pluginkit -m -p com.apple.FileProvider -A

# If not loaded, enable it
pluginkit -e use -i lb.Pokemon.PokemonFileProviderExtension
```

### 3. Connect the Domain

1. Look for the 🔴 icon in your menu bar
2. Click it and select **"Connect Domain"**
3. The icon should turn 🟢 when connected
4. Open Finder - you should see "Pokemon Drive" in the sidebar

### 4. Verify Functionality

1. **Domain appears in Finder**: Look for "Pokemon Drive" in sidebar
2. **Folder structure**: Navigate to Pokemon Drive > Pokemon folder
3. **Files listed**: Should see ~151 `.txt` files named after Pokemon
4. **File content**: Open any file to see basic Pokemon data
5. **Refresh works**: Use menu bar "Refresh" to update data

## Troubleshooting

### Common Issues

#### Extension Not Loading
```bash
# Reset File Provider system
sudo pkill -f com.apple.FileProvider
sudo launchctl bootout system /System/Library/LaunchDaemons/com.apple.FileProvider.plist
sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.FileProvider.plist

# Check extension status
pluginkit -m -v -p com.apple.FileProvider
```

#### Domain Connection Errors

**Error -2001** (NSFileProviderErrorDomain):
- Extension not properly registered
- Try: `pluginkit -r /path/to/Pokemon\ as\ Files.app`

**Error -2014** (NSFileProviderErrorDomain):
- Domain already exists
- Disconnect and reconnect domain

#### Network Issues

- Check internet connection
- Verify PokeAPI is accessible: `curl https://pokeapi.co/api/v2/pokemon?limit=1`
- Check App Transport Security settings in Info.plist

#### Sandbox Issues

- Verify entitlements are correctly applied
- Check App Groups configuration
- Ensure network client entitlement is enabled

### Debug Commands

```bash
# View system logs for File Provider
log stream --predicate 'subsystem == "lb.pokemon"' --level debug

# Check domain status
systemextensionsctl list

# View File Provider domains
pluginkit -m -p com.apple.FileProvider -A

# Reset domain (if needed)
pluginkit -r /Applications/Pokemon\ as\ Files.app
```

### Development Debugging

Add logging to track issues:

```swift
import os.log

private let logger = Logger(subsystem: "lb.pokemon", category: "Debug")
logger.log("Debug message here")
```

View logs in Console.app or Terminal:
```bash
log show --predicate 'subsystem == "lb.pokemon"' --last 1h
```

## API Reference

### PokeAPI Endpoint

The app uses the following PokeAPI endpoint:
- **URL**: `https://pokeapi.co/api/v2/pokemon?limit=151`
- **Response**: JSON with `count`, `next`, `previous`, and `results` array
- **Rate Limit**: Generally permissive, but implement caching for good practice

### File Provider Identifiers

- **Domain ID**: `pokemon`
- **Root Container**: `NSFileProviderItemIdentifier.rootContainer`
- **Pokemon Folder**: `pokemon_folder`
- **Pokemon Files**: `pokemon_{id}` (e.g., `pokemon_1` for Bulbasaur)

## Known Limitations

1. **Read-Only**: Files are virtual and read-only
2. **Basic Content**: Files contain minimal Pokemon data
3. **No Pagination**: Limited to first 151 Pokemon
4. **No Offline Images**: Text files only, no images
5. **System Dependencies**: Requires macOS File Provider system to be functioning

## Future Enhancements

- [ ] Implement file content fetching from individual Pokemon endpoints
- [ ] Add pagination support for all Pokemon
- [ ] Include Pokemon sprites/images
- [ ] Implement alphabetical subfolders (A-Z organization)
- [ ] Add search/filter capabilities
- [ ] Support for additional data (types, stats, etc.)
- [ ] Implement write capabilities (favorites, notes, etc.)

## License

This project is created for educational and demonstration purposes. Pokemon data is provided by [PokeAPI](https://pokeapi.co/).

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Verify all setup steps are completed
3. Check Xcode console for error messages
4. Review system logs for File Provider messages

---

**Note**: This is a technical demonstration project. The File Provider Extension framework requires careful attention to sandbox permissions, App Groups configuration, and system extension registration.