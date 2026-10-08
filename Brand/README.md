# Handoff 005 — Idea Fold

The reviewer selected **A — Idea Fold** in the implementation conversation on 2026-10-07, before production assets were made. The original [three directions](Handoff005-directions.svg) are retained as decision evidence.

## Final direction

An ivory page/card with a gold fold and a bold inset path suggesting an L. One silhouette, generous margins and no readable text keep the mark clear at home-screen size. The palette is deep teal, warm ivory and restrained gold. The outer source remains square; iOS supplies its own mask.

- [Any source](IdeaFold-Any.svg): teal `#174E4B`, ivory `#F7F3E8`, gold `#C7A76B`.
- [Dark source](IdeaFold-Dark.svg): deeper teal `#102C2C`, softened ivory `#E9E5D7`, gold `#BE9E65`.
- [Tinted source](IdeaFold-Tinted.svg): grayscale luminance design for the system's chosen tint.

The production asset set is `LifeIsLearned/Resources/Assets.xcassets/AppIcon.appiconset`, with three opaque sRGB 1024×1024 PNGs. Xcode selects AppIcon for both Debug and Release. Only these compiled assets enter the app bundle; design studies and the renderer stay here.

## Reproduce

From the repository root on macOS:

```sh
swift Brand/render-icon.swift
```

The renderer contains the original vector construction and writes matching SVGs and PNGs without external dependencies. No generated raster artwork, third-party logo, font or external image is used. Keep shape coordinates and palette changes in this renderer so exported assets stay reproducible.

Build, installed home-screen evidence and remaining physical checks are documented in [005F evidence](../Evidence/Handoff005/005F-brand/README.md).
