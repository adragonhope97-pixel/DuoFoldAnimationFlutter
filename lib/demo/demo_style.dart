import 'package:flutter/widgets.dart';

/// The light-appearance iOS colours that `control_panel.dart` still asks
/// for. Everything else this file used to hold described the
/// `DemoContentView.swift` port, which 007 replaced with the
/// debojyoticodes.in screen; those tokens now live in
/// `portfolio_tokens.dart`.
///
/// The control panel is chrome around the effect, not part of the interface
/// behind the glass, so it stays SwiftUI-derived and keeps these literals.

/// `Color.accentColor` — the app tint, which defaults to systemBlue.
const Color kAccentColor = Color(0xFF007AFF);

/// `.systemGreen` — the manual-tilt toggle's on colour.
const Color kSystemGreen = Color(0xFF34C759);

/// `.primary` / `UIColor.label`.
const Color kLabel = Color(0xFF000000);

/// `.tertiary` / `UIColor.tertiaryLabel` (#3C3C43 at 30 %).
const Color kTertiaryLabel = Color(0x4D3C3C43);
