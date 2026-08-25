# Deferred Features & Future Release Planning

The following features were evaluated during specification gap analysis and deliberately deferred to subsequent milestones to preserve core stability, offline simplicity, and lean package footprint:

---

## 1. Gap 17: Text & Freehand Annotation Layer
- **Description**: Interactive drawing canvas, freehand pen markup, text note boxes, highlighter pens, and sticky annotations directly on PDF pages.
- **Rationale for Deferral**: Requires complex vector canvas state serialization, pressure sensitivity curves, undo trees per stroke, and font embedding across arbitrary mobile OS versions.
- **Target Release**: Future Major Release (v2.0).

---

## 2. Gap 18: In-App Multi-Select Gallery with Custom Album Organization
- **Description**: A full custom media gallery browser embedded in the app showing custom phone folder trees, nested album filtering, and custom multi-touch selection grids.
- **Rationale for Deferral**: The OS-native media picker supplied by `image_picker` (supporting multi-selection of 2–100 photos, system albums, recent captures, and cloud storage providers transparently) fully satisfies the core requirements while respecting Android Photo Picker and iOS PHPicker security sandboxes.
- **Target Release**: Future Feature Release (v1.5).
