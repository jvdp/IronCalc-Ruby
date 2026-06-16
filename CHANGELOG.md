## 0.7.1.3

- fix build-provenance and setup github releases

## 0.7.1.2

- Ship precompiled native gems for common platforms (Linux, macOS, Windows),
  so installing no longer rebuilds the IronCalc engine from source
- Publish via RubyGems Trusted Publishing with SigStore build provenance

## 0.7.1.1

- Fix build: remove internal crate version

## 0.7.1.0

- First release
- Ruby bindings for the IronCalc spreadsheet engine (engine 0.7.1)
- Raw API (`IronCalc::Model`) and user API (`IronCalc::UserModel`)
- Load/save xlsx and the internal icalc binary format
