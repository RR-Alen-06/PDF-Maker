# Design Tokens & UI Architecture (DESIGN.md)

This document serves as the visual and stylistic single source of truth for **Photo-to-PDF Maker**.

---

## 1. Color Palette (Cyberpunk Neon & Clean Modern)

### Primary Colors
- `primary`: `#6D28D9` (Deep Neon Violet)
- `primaryLight`: `#8B5CF6` (Bright Lavender Violet)
- `primaryDark`: `#4C1D95` (Dark Midnight Purple)
- `secondary`: `#06B6D4` (Electric Cyan)
- `tertiary`: `#F59E0B` (Vibrant Amber / Gold)
- `neonPink`: `#EC4899` (Hot Magenta)
- `neonEmerald`: `#10B981` (High-visibility Green)
- `error`: `#EF4444` (Vibrant Crimson)
- `success`: `#10B981` (Emerald)

### Backgrounds & Surfaces
- `bgDark`: `#0F0A1C` (Deepest Cyberpunk Indigo)
- `surfaceDark`: `#160C30` (Rich Dark Surface)
- `surfaceContainerDark`: `#201242` (Elevated Container)
- `bgLight`: `#F5F3FF` (Subtle Lavender Mist)
- `surfaceLight`: `#FFFFFF` (Pure Crisp White)
- `surfaceContainerLight`: `#EDE9FE` (Soft Tinted Card)

---

## 2. Typography Scale (Google Fonts: Sora & JetBrains Mono)
- **Display / Headers**: `GoogleFonts.sora` (Weights: 600 SemiBold, 700 Bold, 800 ExtraBold)
- **Body / Content**: `GoogleFonts.sora` / standard typography (Weights: 400 Regular, 500 Medium)
- **Code / Badges / Numbers**: `GoogleFonts.jetBrainsMono` (Weights: 700 Bold, 900 Black)

---

## 3. Responsive Breakpoints & Dimensions
- **Compact**: `< 600 dp` (Single column cards, full width preview, responsive padding)
- **Medium**: `600–840 dp` (2-column layout grid, side-by-side toolbar)
- **Expanded**: `> 840 dp` (3-column layout grid, master-detail presentation)
- **Minimum Tap Target**: `48x48 dp` for all buttons, toggles, icons, and interactive elements.
- **Corner Radii**:
  - Small elements / badges: `6–8 dp`
  - Cards & modals: `14–20 dp`
  - Floating action buttons & sheet top bars: `24 dp`
