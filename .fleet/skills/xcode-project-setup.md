---
id: xcode-project-setup
name: Xcode Firebase Project & SPM Integration
author: Firebase / Google
platform: apple
repository: firebase/skills
path: skills/xcode-project-setup
default: true
description: Safely modifies Xcode projects (.pbxproj) to add Swift Packages (e.g. Firebase) and link client configuration files.
---

# Xcode Firebase Project & SPM Integration

Authoritative guidance for safely integrating Firebase Swift Packages into Apple platform Xcode projects.

## Key Principles

1. **Modern Folder Synchronization**: Modern Xcode projects utilize folder synchronization. Place `GoogleService-Info.plist` and source code directly into the target source directory on disk rather than manually hacking `.pbxproj`.
2. **Swift Package Manager**: Add Firebase dependencies via Xcode SPM (`https://github.com/firebase/firebase-ios-sdk`) targeting only required products (e.g. `FirebaseFirestore`, `FirebaseAuth`, `FirebaseCrashlytics`).
3. **Anti-Ruby Mandate**: Never execute Ruby gems or scripts (such as legacy `xcodeproj`) to manipulate Xcode configurations. Use Swift scripting or native SPM where automation is necessary.
4. **Initialization Discipline**: Call `FirebaseApp.configure()` once early in application launch inside `App.init()` or `@main struct MyApp: App`.
