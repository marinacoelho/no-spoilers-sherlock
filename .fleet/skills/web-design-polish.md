---
id: web-design-polish
name: Modern UI Design Polish & Micro-Interactions
author: FleetKit Design Guild
platform: web
repository: emilkowalski/design-system
default: true
description: Micro-interactions, spring animations, layout shift prevention, dark mode polish.
---

# Modern UI Design Polish & Micro-Interactions

Design engineering standards for crafting fluid, high-polish web interfaces with native tactile responsiveness.

## Key Principles

1. **Physically-Modeled Motion**: Use spring-based animations with appropriate damping rather than linear or abrupt cubic-bezier transitions for dialogs, drawer expansions, and hover states.
2. **Zero Cumulative Layout Shift (CLS)**: Always provide explicit aspect ratios, image placeholders, and skeleton loaders to reserve layout dimensions before dynamic content renders.
3. **Tactile Feedback & States**: Provide immediate visual feedback for all pointer events: active scale depression (`active:scale-[0.98]`), hover tints, and focus rings.
4. **System-Aware Dark Mode**: Implement dark mode with proper neutral surface hierarchies (layering elevated cards above darker baselines) rather than inverted white-to-black color inversions.
5. **Subtle Elevation & Borders**: Use semi-transparent borders (`border-black/5 dark:border-white/10`) paired with diffused multi-stop drop shadows for depth and visual separation.
