# Platform Support

This document explains the current platform status of `SwiftF1Telemetry` and what still needs to be built for non-Apple consumers.

## Current Status

### Apple platforms

The package is actively developed and validated on Apple platforms.

Current supported Apple deployment targets:

- iOS 17+
- macOS 14+

This is the primary supported environment today.

### Linux

The core package is being shaped to work cleanly outside Apple platforms.

Current Linux-oriented improvements include:

- Foundation-based networking with `FoundationNetworking` support where needed
- cross-platform hashing through `swift-crypto` instead of `CryptoKit`
- a more portable default cache-directory strategy
- public telemetry and session models that are easier to serialize and bridge

Linux should be considered a realistic target for the core package, but it still needs ongoing validation in CI and broader runtime testing.

### Android

The repository is **not yet a Kotlin-ready Android library**.

What is true today:

- the Swift core is being prepared to be less Apple-specific
- the package is being made friendlier to Android-oriented Swift toolchains
- public data models are better suited for future bridge layers

What is **not** done yet:

- no JNI wrapper
- no Kotlin/Java-facing Android API
- no Android app packaging
- no Flutter plugin

So the current status is best described as:

- **Android-ready core work in progress**
- **not yet Android app integration ready**

## What “Android-ready core” Means

In this repository, “Android-ready core” means the Swift package itself is being prepared so it can eventually sit under an Android integration layer.

That includes:

- avoiding Apple-only dependencies in the core
- keeping filesystem behavior portable
- using cross-platform Swift package dependencies where appropriate
- keeping models easy to encode and decode
- avoiding UI framework assumptions in the library target

It does **not** mean the Swift package can already be dropped directly into a Kotlin Android app without extra work.

## What Is Needed for Kotlin / Java Integration

To use `SwiftF1Telemetry` from a standard Android app written in Kotlin or Java, a native bridge layer still needs to be added.

That future layer will likely include:

1. a Swift library compiled for Android
2. a JNI wrapper layer
3. Kotlin-facing API types
4. serialization or DTO mapping between Swift and Kotlin

In practice, the recommended approach is to keep the core Swift API strongly typed while exposing bridge-friendly shapes, likely JSON or bridge DTOs, at the Android boundary.

## What Is Needed for Flutter Integration

Flutter does not call Swift directly in a fully cross-platform way.

To use this library from Flutter, the usual architecture would be:

1. Dart API
2. platform plugin implementation
3. native platform bridge
4. `SwiftF1Telemetry` core

That means:

- on iOS/macOS, Flutter can call into native Swift code more directly
- on Android, Flutter would still depend on a Kotlin/Java bridge, which would in turn depend on an Android-compatible Swift layer

So Flutter support depends on the same Android native bridge work described above.

## Recommended Architecture Path

The intended path for this project is:

1. keep `SwiftF1Telemetry` as a pure Swift core package
2. make the core as portable as practical
3. add an Android bridge layer on top of the core
4. add a Flutter plugin on top of the native platform layers if needed

This keeps the Swift package reusable in:

- Apple apps
- command-line tools
- server-side or Linux-oriented tools
- future Android and Flutter integrations

## Summary

Today:

- Apple platforms: supported
- Linux: core portability improving, needs more validation
- Android: core preparation in progress, integration layer still missing
- Flutter: feasible later, but depends on native platform bridges
