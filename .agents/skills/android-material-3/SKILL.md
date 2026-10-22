---
name: Material Design 3 & Edge-to-Edge
description: Material Design 3, dynamic color theming, edge-to-edge system bars (enableEdgeToEdge), and predictive back gesture animations.
---

# Material Design 3 & Edge-to-Edge

Standards and idioms for building modern, expressive Android UIs using Material Design 3 and Android 15 edge-to-edge guidelines.

## Key Principles

1. **Edge-to-Edge Enforcement**: Always invoke `enableEdgeToEdge()` inside `ComponentActivity.onCreate()` before `setContent`. Never rely on legacy translucent system bar flags.
2. **WindowInsets Consumption**: Use `Modifier.safeDrawingPadding()`, `Modifier.windowInsetsPadding()`, or `WindowInsets.safeDrawing` to inset interactive content away from system bars and display cutouts.
3. **Dynamic Theming**: Support dynamic color palettes on Android 12+ using `dynamicLightColorScheme(context)` and `dynamicDarkColorScheme(context)` with elegant fallbacks.
4. **Predictive Back Gestures**: Adopt `PredictiveBackHandler` in Compose screens to deliver fluid gesture-driven navigation animations.
5. **Component Tokens**: Strictly use `MaterialTheme.colorScheme`, `MaterialTheme.typography`, and `MaterialTheme.shapes` rather than hardcoded hex values or raw pixel dimensions.
