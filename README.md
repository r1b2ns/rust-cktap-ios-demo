# TapsignerDemo

iOS demo app for reading **Coinkite** cards (Tapsigner, SatsCard, SatsChip) over NFC using [rust-cktap](https://github.com/rust-cktap/rust-cktap) (Swift bindings: [`cktap-swift`](../rust-cktap/cktap-swift)).

## TestFlight

Try the latest build without setting up the toolchain:
👉 [Join the TestFlight beta](https://testflight.apple.com/join/jBWyCA3w)

## Requirements

- Xcode 26.4+
- iOS 26.4+ on a physical device (NFC is not supported in the Simulator)
- Apple Developer account with **Near Field Communication Tag Reading** enabled on the App ID
- A Coinkite card (Tapsigner / SatsCard / SatsChip)

## Setup

> **Important:** this project depends on a **local checkout of `rust-cktap`**. The package reference in `TapsignerDemo.xcodeproj` is a `XCLocalSwiftPackageReference` pointing at `../rust-cktap/cktap-swift`, so the two repos must sit side-by-side on disk.

1. **Clone `rust-cktap` next to this project:**
   ```sh
   git clone https://github.com/rust-cktap/rust-cktap.git ../rust-cktap
   ```
   Final layout:
   ```
   <parent-dir>/
   ├── TapsignerDemo/       # this repo
   └── rust-cktap/
       └── cktap-swift/
           ├── Package.swift
           ├── Sources/CKTap/…
           └── cktapFFI.xcframework/
   ```

2. **Build the xcframework** (requires the Rust toolchain — see `rust-cktap/cktap-swift/README.md`):
   ```sh
   cd ../rust-cktap/cktap-swift
   just build          # or ./build-xcframework.sh
   ```
   The xcframework must have `CKTapFFI.h` and `module.modulemap` (declaring `module CKTapFFI`) directly under each slice's `Headers/` directory — not nested under `Headers/cktap_ffiFFI/`.

3. **Generate the Xcode project with XcodeGen:**
   ```sh
   brew install xcodegen   # if you don't have it
   xcodegen generate       # reads project.yml at the repo root
   ```
   The `.xcodeproj` is regenerated from `project.yml`, so re-run `xcodegen generate` whenever you add or remove a source file.

4. **Open and run:**
   - Open `CKTapDemo.xcodeproj` in Xcode.
   - Select a connected physical iPhone.
   - Build & Run. Tap **Scan NFC**, enter the card CVC (6 digits printed on the back), and hold the card against the top of the iPhone.

## License

MIT — see [LICENSE](LICENSE).
