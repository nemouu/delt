# Delt - Remaining Tasks

---

## Priority 1: Sync Implementation (CRITICAL)

### Core Sync Protocol (Required for All Methods)

These files are needed regardless of which transport method we use:

- [ ] **SyncMessage** (`lib/services/sync/sync_message.dart`)
  - [ ] Define message types enum (HANDSHAKE, CHALLENGE, RESPONSE, DATA_REQUEST, DATA_RESPONSE, ACK, ERROR)
  - [ ] Create SyncMessage class with JSON serialization
  - [ ] Add validation for message structure
  - [ ] Unit tests for serialization/deserialization

- [ ] **SyncProtocol** (`lib/services/sync/sync_protocol.dart`)
  - [ ] Implement handshake flow
  - [ ] Add HMAC-SHA256 challenge-response authentication using group secret key
  - [ ] Create data exchange protocol (request/response cycles)
  - [ ] Implement conflict resolution (newest timestamp wins)
  - [ ] Handle sync errors and retries
  - [ ] Unit tests for protocol flows

- [ ] **SyncService** (`lib/services/sync/sync_service.dart`)
  - [ ] Main sync orchestration service
  - [ ] Manage multiple transport types
  - [ ] Coordinate device discovery
  - [ ] Execute sync protocol
  - [ ] Update database with synced data
  - [ ] Emit sync status events (for UI)
  - [ ] Handle sync cancellation
  - [ ] Conflict resolution integration

### Transport Method A: WiFi Direct (Try First)

- [ ] **Research WiFi Direct packages**
  - [ ] Try `wifi_p2p` package - check compatibility, features, examples
  - [ ] Check if platform channels needed
  - [ ] Test on real Android device (WiFi Direct API level requirements)
  - [ ] Document findings and limitations

- [ ] **WiFiDirectTransport** (`lib/services/sync/wifi_direct_transport.dart`)
  - [ ] Initialize WiFi Direct
  - [ ] Create group (host mode)
  - [ ] Discover groups (client mode)
  - [ ] Connect to group
  - [ ] Send/receive data over WiFi Direct socket
  - [ ] Handle connection lifecycle
  - [ ] Error handling and reconnection

- [ ] **Platform Channels** (if needed)
  - [ ] Android: Create native bridge for WiFi P2P APIs
  - [ ] iOS: Research Multipeer Connectivity framework
  - [ ] Method channel setup in Flutter

- [ ] **Testing WiFi Direct**
  - [ ] Test on 2 Android devices
  - [ ] Test connection stability
  - [ ] Test data transfer speed
  - [ ] Test reconnection scenarios
  - [ ] Document device compatibility issues

### Transport Method B: Bluetooth (Try Second)

- [ ] **Research Bluetooth packages**
  - [ ] Try `flutter_blue_plus` package - most popular
  - [ ] Check permissions needed (Android 12+ changes)
  - [ ] Review examples and documentation
  - [ ] Test on real device

- [ ] **BluetoothTransport** (`lib/services/sync/bluetooth_transport.dart`)
  - [ ] Initialize Bluetooth adapter
  - [ ] Start advertising as peripheral (include group UUID in service)
  - [ ] Scan for devices advertising Delt service
  - [ ] Connect to device
  - [ ] Create GATT service for data exchange
  - [ ] Send/receive data in chunks (MTU limitations)
  - [ ] Handle connection lifecycle
  - [ ] Pairing flow with challenge-response

- [ ] **Bluetooth Permissions**
  - [ ] Update AndroidManifest.xml with BLUETOOTH_SCAN, BLUETOOTH_CONNECT, BLUETOOTH_ADVERTISE
  - [ ] Handle runtime permissions for Android 12+
  - [ ] Add iOS Info.plist entries

- [ ] **Testing Bluetooth**
  - [ ] Test on 2 devices
  - [ ] Test data transfer with large groups
  - [ ] Test range limitations
  - [ ] Test in crowded Bluetooth environments
  - [ ] Measure battery impact

### Transport Method C: WiFi Network Sync (Try Third)

- [ ] **Research NSD/mDNS packages**
  - [ ] Try `nsd` package (Network Service Discovery)
  - [ ] Try `multicast_dns` package as alternative
  - [ ] Check Android/iOS compatibility
  - [ ] Review examples and limitations
  - [ ] May need platform channels

- [ ] **WiFiNetworkTransport** (`lib/services/sync/wifi_network_transport.dart`)
  - [ ] Register NSD service (advertise as "_delt._tcp")
  - [ ] Discover NSD services (find other devices)
  - [ ] Create TCP server socket (dart:io ServerSocket) on random port
  - [ ] Create TCP client socket (dart:io Socket) to connect
  - [ ] Send/receive SyncMessage over socket
  - [ ] Handle multiple simultaneous connections
  - [ ] Timeout handling

- [ ] **WiFiNetworkManager** (`lib/services/sync/wifi_network_manager.dart`)
  - [ ] Get current WiFi SSID (use `network_info_plus` package)
  - [ ] Check if connected to trusted network
  - [ ] Listen for network changes
  - [ ] Trigger sync when on trusted WiFi
  - [ ] Handle iOS location permission requirement

- [ ] **Platform Channels for NSD** (if packages insufficient)
  - [ ] Android: Bridge to NsdManager APIs
  - [ ] iOS: Bridge to NetService (Bonjour)
  - [ ] Handle service registration/discovery callbacks

- [ ] **Testing WiFi Network Sync**
  - [ ] Test on same WiFi network
  - [ ] Test service discovery reliability
  - [ ] Test with router AP isolation enabled (should fail gracefully)
  - [ ] Test connection speed
  - [ ] Test with 3+ devices simultaneously

### Sync UI Components

- [ ] **Device Discovery Screen** (`lib/screens/device_discovery_screen.dart`)
  - [ ] Show available devices/groups
  - [ ] Display device name and sync method
  - [ ] Connection status indicators
  - [ ] Manual scan button
  - [ ] Auto-scan toggle setting
  - [ ] Loading spinner during scan

- [ ] **Sync Status Indicator**
  - [ ] Add sync status badge to group cards
  - [ ] Show last synced timestamp
  - [ ] Show "syncing..." animation
  - [ ] Show sync errors with retry option
  - [ ] Show number of pending changes

- [ ] **Sync Settings** (`lib/screens/sync_settings_screen.dart`)
  - [ ] Choose preferred sync method (WiFi Direct / Bluetooth / WiFi Network)
  - [ ] Enable/disable auto-sync
  - [ ] Manage trusted WiFi networks
  - [ ] Manage trusted devices/peers
  - [ ] View sync history/logs
  - [ ] Clear sync cache button

- [ ] **Trusted Device Management**
  - [ ] List of devices that successfully synced
  - [ ] Device fingerprint/ID
  - [ ] Last seen timestamp
  - [ ] Remove device option
  - [ ] Revoke access for lost devices

### Sync Integration & Testing

- [ ] **Integration with existing flows**
  - [ ] Trigger sync after QR code group join
  - [ ] Trigger sync after adding group expense
  - [ ] Trigger sync when opening group details (pull-to-refresh)
  - [ ] Background sync when on trusted WiFi (Android WorkManager?)
  - [ ] Sync notification when in background

- [ ] **Comprehensive Sync Testing**
  - [ ] Test conflict resolution (same expense edited on 2 devices)
  - [ ] Test new member added on both devices simultaneously
  - [ ] Test expense deleted on one device while edited on another
  - [ ] Test large group data (100+ expenses)
  - [ ] Test network interruption during sync
  - [ ] Test app killed during sync
  - [ ] Test battery optimization impact
  - [ ] Test with 3+ devices in same group

- [ ] **Sync Decision & Cleanup**
  - [ ] Pick the best working method based on tests
  - [ ] Remove code for non-chosen methods (keep it clean)
  - [ ] Update README with chosen sync approach
  - [ ] Document sync limitations and best practices

---

## Priority 2: UI Improvements & Polish (partly already implemented)

### Visual Polish

- [ ] **Dark Mode Support**
  - [ ] Implement theme switching
  - [ ] Dark theme color palette
  - [ ] Save theme preference
  - [ ] System theme detection option

- [ ] **Material Design 3**
  - [ ] Update to Material 3 components
  - [ ] Color scheme with seed color
  - [ ] Dynamic color support (Android 12+)
  - [ ] Update typography

- [ ] **Loading States**
  - [ ] Skeleton loaders for lists
  - [ ] Loading overlays for async operations
  - [ ] Progress indicators for long operations
  - [ ] Shimmer effect for loading cards

- [ ] **Error Handling UI**
  - [ ] Better error messages (user-friendly)
  - [ ] Retry buttons where appropriate
  - [ ] Toast/SnackBar for quick feedback
  - [ ] Error illustrations or icons

- [ ] **Empty States**
  - [ ] Illustrations for empty expense lists
  - [ ] Helpful onboarding hints
  - [ ] Clear CTAs for empty states
  - [ ] Fun illustrations (optional)

- [ ] **Animations**
  - [ ] Hero animations for group navigation
  - [ ] List item animations (staggered fade-in)
  - [ ] FAB rotation animation
  - [ ] Smooth tab transitions
  - [ ] Expense card swipe animations

### UX Enhancements

- [ ] **Onboarding Flow**
  - [ ] Welcome screen with app features
  - [ ] Tutorial slides (optional, skippable)
  - [ ] Quick setup wizard
  - [ ] Show only on first launch

- [ ] **Receipt Scanning Improvements**
  - [ ] Better camera preview UI
  - [ ] Crop guides for receipt
  - [ ] Manual amount correction UI
  - [ ] Save receipt image option
  - [ ] Multiple receipt formats support

- [ ] **Expense Filters & Search**
  - [ ] Filter personal expenses by category
  - [ ] Filter by date range
  - [ ] Search expenses by note/description
  - [ ] Filter group expenses by member

- [ ] **Expense Editing**
  - [ ] Tap expense to edit (currently only swipe-to-delete)
  - [ ] Edit group expenses
  - [ ] Edit history/audit log

- [ ] **Group Settings Enhancements**
  - [ ] Group icon/color customization
  - [ ] Member permissions (who can add expenses)
  - [ ] Settle up flow improvements
  - [ ] Archive/unarchive group

- [ ] **Export Improvements**
  - [ ] Export to CSV format (for Excel/Sheets)
  - [ ] Export to PDF report
  - [ ] Export date range selection
  - [ ] Share export via more apps

### Settings & Features

- [ ] **Notifications**
  - [ ] Local notifications for sync completion
  - [ ] Reminders for unsettled balances (optional)
  - [ ] Daily/weekly expense summary (optional)

- [ ] **Backup Reminders**
  - [ ] Remind user to backup monthly
  - [ ] Show last backup date
  - [ ] Quick backup button in settings

- [ ] **Language Support** (if needed)
  - [ ] Setup i18n framework
  - [ ] Extract all strings to localization files
  - [ ] Add translations (start with English, German?)
  - [ ] Language selector in settings

---

## Priority 3: Advanced Features (ideas for now - came from brainstorming)

### Financial Features

- [ ] **Currency Conversion**
  - [ ] Fetch exchange rates from API (or offline rates)
  - [ ] Convert expenses to base currency for totals
  - [ ] Show amounts in multiple currencies
  - [ ] Cache rates for offline use

- [ ] **Budget Tracking**
  - [ ] Set monthly budget per category
  - [ ] Budget progress indicators
  - [ ] Budget alerts when nearing limit
  - [ ] Budget vs actual comparison charts

- [ ] **Recurring Expenses**
  - [ ] Add recurring expense template
  - [ ] Auto-create expenses on schedule
  - [ ] Edit/delete recurring template
  - [ ] Background job for recurring creation

- [ ] **Spending Analytics**
  - [ ] Category breakdown pie chart
  - [ ] Spending trends over time (line chart)
  - [ ] Month-over-month comparison
  - [ ] Export analytics as image/PDF

### Group Features

- [ ] **Unequal Splitting**
  - [ ] Percentage-based splits
  - [ ] Custom amount per member
  - [ ] Split by shares (1x, 2x, etc.)
  - [ ] Save split templates

- [ ] **Multiple Payers**
  - [ ] Support multiple people paying for one expense
  - [ ] Complex split scenarios
  - [ ] IOU tracking

- [ ] **Group Chat/Notes**
  - [ ] Simple group timeline/feed
  - [ ] Comments on expenses
  - [ ] @mention members
  - [ ] Offline-first, sync with group data

### Technical Improvements

- [ ] **Database Optimization**
  - [ ] Add more indices for common queries
  - [ ] Optimize balance calculation queries
  - [ ] Pagination for large expense lists
  - [ ] Database vacuum on cleanup

- [ ] **Performance Testing**
  - [ ] Profile app with large datasets
  - [ ] Optimize widget rebuilds
  - [ ] Lazy loading for long lists
  - [ ] Image caching for receipts

- [ ] **Automated Testing**
  - [ ] Unit tests for services
  - [ ] Widget tests for key screens
  - [ ] Integration tests for critical flows
  - [ ] Test coverage reporting

- [ ] **CI/CD Setup**
  - [ ] GitHub Actions workflow
  - [ ] Automated builds
  - [ ] Automated testing
  - [ ] Release automation

---

**Last Updated:** 2025-12-18
**Current Status:** Sync research and implementation phase
**Next Milestone:** Get one sync method working end-to-end
