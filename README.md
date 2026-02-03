# WishWithMe iOS App

Native iOS app for WishWithMe - a wishlist management platform built with Swift and SwiftUI.

## Features

- Create and manage wishlists
- Add items manually or via URL (auto-resolves from marketplaces)
- Share wishlists via link or QR code
- Follow friends' wishlists
- Offline-first architecture with sync
- Multi-language support (English, Russian)

## Tech Stack

- **Swift 5.9+** / **SwiftUI**
- **iOS 16.0+** minimum deployment
- **SwiftData** for local persistence
- **Keychain** for secure token storage
- **MVVM + Repository** architecture

## Development

### Prerequisites

- Xcode 15.2+
- macOS 14.0+
- Swift 5.9+

### Getting Started

1. Clone the repository:
   ```bash
   git clone https://github.com/mrkutin/wish-with-me-iphone.git
   cd wish-with-me-iphone
   ```

2. Open the project in Xcode:
   ```bash
   open WishWithMe.xcodeproj
   ```

3. Build and run on simulator or device

### Project Structure

```
WishWithMe/
├── App/                    # App entry point
├── Core/                   # Network, Persistence, Auth
├── Models/                 # Data models
├── Features/               # Feature modules (MVVM)
│   ├── Auth/
│   ├── Wishlists/
│   ├── Items/
│   ├── Sharing/
│   └── Profile/
├── Resources/              # Assets, Localization
└── Tests/                  # Unit and UI tests
```

## Claude Code Integration

This project is developed with [Claude Code](https://claude.ai/code) for autonomous development.

### Using Claude Code

```bash
# Install Claude Code CLI
npm install -g @anthropic-ai/claude-code

# Start development session
claude

# Or run specific commands
claude "implement the login screen"
```

### Development Workflow

The project uses specialized agents for different tasks:

| Task | Agent |
|------|-------|
| Architecture decisions | ios-architect |
| Feature implementation | ios-dev |
| Code review | reviewer |
| Security audit | security |
| Test strategy | qa |
| Accessibility | accessibility |

Agents automatically forward tasks to each other when needed.

### Check Progress

You can check development progress from any device:

1. **GitHub Issues/PRs**: Track feature progress
2. **GitHub Actions**: View build/test status
3. **Claude Code**: Resume sessions from Mac or iPhone

## API

Backend API: `https://api.wishwith.me`

See [CLAUDE.md](./CLAUDE.md) for detailed API documentation.

## Contributing

1. Create a feature branch
2. Implement changes
3. Submit PR for review
4. Agents will validate code quality, security, and tests

## License

Private - All rights reserved
