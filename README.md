# Delt

> **Beta Release** - Fully functional expense splitting app with automatic sync coming soon!

**Privacy-first expense splitting app**

No accounts. No cloud. No tracking. Your data stays on your device.

## Features

### Currently Working

- **Personal Expense Tracking** - Track your daily expenses with categories
- **Group Expense Splitting** - Split expenses fairly with friends
- **QR Code Pairing** - Join groups by scanning QR codes
- **Encrypted Database** - SQLCipher encryption with PIN protection
- **Manual Export/Import** - Backup and share group data securely via encrypted files
- **Receipt Scanning** - OCR-powered receipt scanning with automatic amount extraction
- **Balance Calculations** - Automatic calculation of who owes whom
- **Settlement Optimization** - Minimize number of transactions needed
- **Privacy-First** - No accounts, no cloud servers, no analytics

### In Development

- **Automatic Device Sync** - Real-time sync between devices (planned methods: WiFi Direct, Bluetooth, or WiFi Network)
  - Currently: Manual export/import works as a workaround

## Tech Stack

- **Flutter** - Cross-platform UI framework
- **sqflite_sqlcipher** - Encrypted local database
- **Provider** - State management
- **mobile_scanner** - QR code scanning
- **encrypt** - File encryption for export/import

## Project Structure

```
lib/
  models/       # Data models (User, Group, Expense, etc.)
  database/     # Database setup and DAOs
  services/     # Business logic and sync
  screens/      # UI screens
  widgets/      # Reusable UI components
  utils/        # Helper functions
```

## Development

### Prerequisites

- Flutter SDK (3.7.2+)
- Android Studio / VS Code
- Android device or emulator (recommended for testing)

### Setup

```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build APK
flutter build apk --release
```

### Testing Status

**Important:** This app has been tested primarily in development/emulator environments. Real device testing is limited. Please report any issues you encounter!

- ✅ Code quality verified (0 Flutter analyze issues)
- ✅ Basic functionality tested
- ⏳ Extensive real-world device testing needed
- ⏳ Edge cases and stress testing needed

## Current Status

**Version:** Beta - Feature Complete (except sync)

Delt is fully functional with robust core features:

- ✅ Complete UI with 16 screens and intuitive navigation
- ✅ Military-grade database encryption (SQLCipher + PIN)
- ✅ Secure export/import with AES encryption
- ✅ AI-powered receipt scanning with OCR
- ✅ Production-ready code (0 analyzer warnings)
- ⏳ Automatic device sync in development (see `todo.md` for roadmap)

The app is **ready to use today**. Manual export/import provides a reliable way to share groups between devices while automatic sync is being developed.

## Privacy

- All data stored locally in encrypted database (SQLCipher)
- No analytics or tracking
- No internet connection required (except for optional local network sync)
- No accounts or sign-ups
- Open source - you can audit the code yourself

## Contributing

Contributions are welcome! This project is especially looking for help with:

- Implementing device sync (WiFi Direct, Bluetooth, or WiFi Network)
- Testing on various Android devices
- UI/UX improvements
- Bug reports and feature requests

Please see `todo.md` for the current roadmap.

## License

MIT License - see [LICENSE](LICENSE) file for details.

This means you're free to use, modify, and distribute this code for any purpose, including commercial use.
