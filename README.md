# 📄 Photo-to-PDF Maker (Flutter)

A modern, production-grade, offline-first mobile application built with Flutter that transforms photos, documents, and camera scans into beautifully formatted, high-performance PDFs with comprehensive utility tooling.

---

## ✨ Features

### 📸 Photo & Document to PDF Converter
- **Multi-Image Import**: Seamlessly pick multiple photos from gallery or snap high-res shots directly via camera.
- **Image Editing & Cropping**: Built-in crop and rotation controls with intuitive aspect ratio presets.
- **Page Layout Customization**:
  - Page formats: `A4`, `US Letter`, `Legal`, `Executive`, `A3`, `A5`, and custom dimensions.
  - Page orientation: Portrait and Landscape.
  - Configurable page margins (Zero, Normal, Compact, Wide).
  - Image scaling modes: Fit to Page, Fill / Stretch, Center with original aspect ratio.
- **Compression & Optimization**: Select from Low, Medium, High, or Maximum compression to balance clarity and file size.
- **Metadata & Watermarking**: Add custom document titles, author details, page numbers, and text watermarks.
- **Password Protection & Encryption**: Secure documents using industry-standard PDF password encryption.

### 🛠️ PDF Utility Suite
- **Merge PDFs**: Combine multiple PDF documents into a single organized file.
- **Split PDF**: Extract selected page ranges or split documents page-by-page.
- **Compress PDF**: Optimize and downscale existing PDFs to reduce storage and email attachment footprints.
- **Extract Images**: Extract embedded full-resolution images from any PDF file.
- **Reorder Pages**: Drag-and-drop page organizer to quickly rearrange, rotate, or delete individual pages.

### 📂 History & File Management
- **Local SQLite History**: Keeps a track record of generated and manipulated PDFs.
- **Integrated PDF Viewer & Share Sheet**: In-app PDF preview, native Android/iOS system sharing, printing support, and export to external storage.
- **Batch Management**: Delete or bulk-share documents directly from the History dashboard.

### 🎨 Cyberpunk Neon & Clean Modern UI
- **Design System**: Distinctive cyberpunk neon visual aesthetic with deep midnight violet backgrounds (`#0F0A1C`), neon electric cyan accents (`#06B6D4`), and crisp typography.
- **Google Fonts**: Powered by *Sora* for clean headings/body and *JetBrains Mono* for badges, metrics, and file size counters.
- **Theme Modes**: Full support for Dark and Light theme preferences.

---

## 🏗️ Architecture & Tech Stack

- **Framework**: [Flutter](https://flutter.dev/) (Targeting Android & iOS)
- **State Management**: [Riverpod](https://riverpod.dev/) (`flutter_riverpod`)
- **PDF Engine**: [`pdf`](https://pub.dev/packages/pdf), [`printing`](https://pub.dev/packages/printing), and [`syncfusion_flutter_pdf`](https://pub.dev/packages/syncfusion_flutter_pdf)
- **Image Processing**: [`image`](https://pub.dev/packages/image), [`image_cropper`](https://pub.dev/packages/image_cropper), [`flutter_image_compress`](https://pub.dev/packages/flutter_image_compress)
- **Database & Storage**: [`sqflite`](https://pub.dev/packages/sqflite), [`shared_preferences`](https://pub.dev/packages/shared_preferences), [`path_provider`](https://pub.dev/packages/path_provider)
- **File & Hardware Access**: [`image_picker`](https://pub.dev/packages/image_picker), [`file_picker`](https://pub.dev/packages/file_picker), [`share_plus`](https://pub.dev/packages/share_plus), [`permission_handler`](https://pub.dev/packages/permission_handler), [`open_filex`](https://pub.dev/packages/open_filex)

---

## 📁 Project Structure

```text
lib/
├── core/
│   ├── constants/       # App constants & dimension tokens
│   ├── database/        # SQLite helpers & migrations
│   ├── theme/           # Color palettes, typography & ThemeData
│   └── utils/           # File helpers, formatting, and permissions
├── features/
│   ├── home/            # Dashboard & quick-action cards
│   ├── photo_to_pdf/    # Image import, editor, settings, & generation
│   ├── tools/           # PDF Merge, Split, Compress, Extract, Reorder
│   ├── history/         # Generated documents history & file actions
│   └── settings/        # App preferences, theme toggle, and info
└── main.dart            # Application entry point & provider scope
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version `>=3.0.0 <4.0.0`)
- Android Studio / Xcode for device simulation and compilation.

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/RR-Alen-06/PDF-Maker.git
   cd PDF-Maker
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the app**:
   ```bash
   flutter run
   ```

---

## 📄 License & Attribution

This project is licensed under the terms described in [LICENSES.md](LICENSES.md).
