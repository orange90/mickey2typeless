# Contributing to MicKey

Thanks for contributing. MicKey handles low-level HID input, so focused changes and explicit hardware test notes are especially helpful.

## Development setup

1. Install macOS 26, Xcode 26, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
2. Run `xcodegen generate`.
3. Run `./scripts/check_localizations.sh`.
4. Build and test with the commands in `README.md`.

Create a focused branch, include tests where practical, and open a pull request using the repository template. Keep Simplified Chinese and English localization keys in sync.

Hardware-dependent changes should list the receiver transport, VID/PID, Usage Page, and Usage tested. Do not publish device serial numbers, signing credentials, notarization credentials, or other private data.
