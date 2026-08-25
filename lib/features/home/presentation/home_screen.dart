import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/utils/file_utils.dart';
import 'package:pdf_maker/features/history/presentation/history_screen.dart';
import 'package:pdf_maker/features/settings/presentation/settings_screen.dart';
import 'package:pdf_maker/features/history/services/history_storage_service.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/controllers/photo_to_pdf_controller.dart';
import 'package:pdf_maker/features/photo_to_pdf/presentation/screens/photo_arranger_screen.dart';
import 'package:pdf_maker/features/tools/image_compressor/presentation/image_compressor_screen.dart';
import 'package:pdf_maker/features/tools/pdf_compressor/presentation/pdf_compressor_screen.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/presentation/pdf_merge_screen.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/presentation/pdf_password_screen.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/presentation/pdf_split_screen.dart';
import 'package:pdf_maker/features/tools/pdf_manipulation/presentation/pdf_page_editor_screen.dart';
import 'package:pdf_maker/features/tools/scan_mode/presentation/scan_mode_screen.dart';
import 'package:pdf_maker/features/tools/pdf_to_images/presentation/pdf_to_images_screen.dart';
import 'package:pdf_maker/features/tools/batch_processing/presentation/batch_processing_screen.dart';
import 'package:pdf_maker/features/settings/presentation/export_settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final HistoryStorageService _storageService = HistoryStorageService();
  List<HistoryItem> _recentFiles = [];
  bool _loadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadRecentFiles();
    FileUtils.cleanupStaleTempFiles();
  }

  Future<void> _loadRecentFiles() async {
    try {
      final items = await _storageService.getAllHistory();
      if (mounted) {
        setState(() {
          _recentFiles = items.take(5).toList();
          _loadingRecent = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingRecent = false);
      }
    }
  }

  void _showPermissionRationaleDialog(String message, bool isCamera) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isCamera ? Icons.camera_alt_outlined : Icons.photo_library_outlined,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'Permission Required',
              style: GoogleFonts.sora(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _checkSkippedFilesAndWarnings() {
    final pdfState = ref.read(photoToPdfProvider);

    // 1. Show unsupported skipped files snackbar
    if (pdfState.unsupportedSkippedFiles.isNotEmpty) {
      final skippedList = pdfState.unsupportedSkippedFiles.join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skipped unsupported image files: $skippedList'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 5),
          showCloseIcon: true,
        ),
      );
      ref.read(photoToPdfProvider.notifier).clearSkippedFilesNotification();
    }

    // 1b. Suggestion 23: Duplicate Photo Detection Notification
    if (pdfState.duplicateSkippedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${pdfState.duplicateSkippedCount} duplicate photo(s) skipped.'),
          backgroundColor: AppColors.tertiary,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // 2. Show inline validation warning if < 2 photos
    if (pdfState.validationWarning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                pdfState.validationWarning!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      ref.read(photoToPdfProvider.notifier).clearWarning();
    }

    // 3. Permission denied needs settings dialog
    if (pdfState.permissionDeniedNeedSettings && pdfState.permissionDeniedMessage != null) {
      _showPermissionRationaleDialog(pdfState.permissionDeniedMessage!, false);
      ref.read(photoToPdfProvider.notifier).clearPermissionError();
    }
  }

  Future<void> _handlePhotoPicking() async {
    await ref.read(photoToPdfProvider.notifier).pickPhotosFromGallery();
    _checkSkippedFilesAndWarnings();

    final count = ref.read(photoToPdfProvider).photos.length;
    if (count >= 2 && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PhotoArrangerScreen()),
      );
      _loadRecentFiles();
    }
  }

  Future<void> _handleCameraCapture() async {
    await ref.read(photoToPdfProvider.notifier).takePhotoFromCamera();
    _checkSkippedFilesAndWarnings();

    final count = ref.read(photoToPdfProvider).photos.length;
    if (count >= 2 && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PhotoArrangerScreen()),
      );
      _loadRecentFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRecentFiles,
          color: AppColors.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // Top App Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      // Glowing Brand Logo
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppColors.neonGlow(AppColors.primary,
                              opacity: 0.4, blur: 14),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'PDF STUDIO',
                                  style: GoogleFonts.sora(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: AppColors.cyanVioletGradient,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'PRO',
                                    style: GoogleFonts.jetBrainsMono(
                                      color: Colors.black,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Smart Document Studio',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // History Action
                      _buildHeaderAction(
                        icon: Icons.history_rounded,
                        tooltip: 'History',
                        isDark: isDark,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HistoryScreen()),
                          );
                          _loadRecentFiles();
                        },
                      ),
                      const SizedBox(width: 8),
                      // Settings Action
                      _buildHeaderAction(
                        icon: Icons.tune_rounded,
                        tooltip: 'Settings',
                        isDark: isDark,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Content Body
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Hero Banner: Photo to PDF
                    _buildHeroBanner(context, isDark),
                    const SizedBox(height: 20),

                    // Feature highlights bar
                    _buildFeaturePills(isDark),
                    const SizedBox(height: 28),

                    // Section: Tools Grid Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'PDF Tools & Utilities',
                          style: GoogleFonts.sora(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceContainerDark
                                : AppColors.surfaceContainerLight,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '6 TOOLS',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // 2-Column Bold Tool Grid
                    _buildToolGrid(context, isDark),
                    const SizedBox(height: 28),

                    // Section: Recent Files Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Documents',
                          style: GoogleFonts.sora(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (_recentFiles.isNotEmpty)
                          TextButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const HistoryScreen()),
                              );
                              _loadRecentFiles();
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            child: const Row(
                              children: [
                                Text('View All',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward_ios_rounded, size: 12),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Recent Files Horizontal Carousel
                    _buildRecentSection(context, isDark),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isDark
          ? AppColors.surfaceContainerDark
          : AppColors.surfaceContainerLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.neonGlow(AppColors.primary, opacity: 0.35, blur: 24),
      ),
      child: Stack(
        children: [
          // Background decorative glow shapes
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -30,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(22.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Tag
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded,
                              size: 14, color: AppColors.tertiary),
                          const SizedBox(width: 4),
                          Text(
                            'CORE ENGINE',
                            style: GoogleFonts.jetBrainsMono(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Headline
                Text(
                  'Photo to High-Res PDF',
                  style: GoogleFonts.sora(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Combine multiple photos, arrange grid layouts, apply smart scan filters & export.',
                  style: GoogleFonts.sora(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Hero CTA Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _handlePhotoPicking,
                        icon: const Icon(Icons.add_photo_alternate_rounded,
                            color: Color(0xFF160C30), size: 20),
                        label: Text(
                          'Pick Photos',
                          style: GoogleFonts.sora(
                            color: const Color(0xFF160C30),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3), width: 1),
                      ),
                      child: IconButton(
                        iconSize: 22,
                        padding: const EdgeInsets.all(13),
                        color: Colors.white,
                        onPressed: _handleCameraCapture,
                        icon: const Icon(Icons.camera_alt_rounded),
                        tooltip: 'Camera Scan',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePills(bool isDark) {
    final pills = [
      {'icon': Icons.lock_outline_rounded, 'label': '100% Offline', 'color': AppColors.neonEmerald},
      {'icon': Icons.flash_on_rounded, 'label': 'Fast Engine', 'color': AppColors.tertiary},
      {'icon': Icons.high_quality_rounded, 'label': 'Ultra HD', 'color': AppColors.secondary},
    ];

    return Row(
      children: pills.map((p) {
        final color = p['color'] as Color;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceContainerDark.withValues(alpha: 0.7)
                  : AppColors.surfaceContainerLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? color.withValues(alpha: 0.2)
                    : color.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(p['icon'] as IconData, size: 14, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    p['label'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.sora(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildToolGrid(BuildContext context, bool isDark) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 1.15,
      children: [
        _buildVibrantToolCard(
          title: 'Merge PDFs',
          subtitle: 'Combine docs',
          icon: Icons.call_merge_rounded,
          gradient: AppColors.pinkOrangeGradient,
          glowColor: AppColors.primary,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PdfMergeScreen()),
            );
            _loadRecentFiles();
          },
        ),
        _buildVibrantToolCard(
          title: 'Split PDF',
          subtitle: 'Extract pages',
          icon: Icons.call_split_rounded,
          gradient: AppColors.amberOrangeGradient,
          glowColor: AppColors.tertiary,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PdfSplitScreen()),
            );
            _loadRecentFiles();
          },
        ),
        _buildVibrantToolCard(
          title: 'Compress PDF',
          subtitle: 'Reduce size',
          icon: Icons.picture_as_pdf_rounded,
          gradient: AppColors.cyanVioletGradient,
          glowColor: AppColors.secondary,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PdfCompressorScreen()),
            );
            _loadRecentFiles();
          },
        ),
        _buildVibrantToolCard(
          title: 'Compress Images',
          subtitle: 'Batch shrink',
          icon: Icons.compress_rounded,
          gradient: AppColors.violetIndigoGradient,
          glowColor: AppColors.neonViolet,
          isDark: isDark,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const ImageCompressorScreen()),
            );
          },
        ),
        _buildVibrantToolCard(
          title: 'PDF Security',
          subtitle: 'Password protect',
          icon: Icons.lock_rounded,
          gradient: AppColors.primaryGradient,
          glowColor: AppColors.primaryLight,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const PdfPasswordScreen()),
            );
            _loadRecentFiles();
          },
        ),
        _buildVibrantToolCard(
          title: 'PDF Page Editor',
          subtitle: 'Reorder & rotate',
          icon: Icons.dashboard_customize_rounded,
          gradient: AppColors.violetIndigoGradient,
          glowColor: AppColors.neonViolet,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PdfPageEditorScreen()),
            );
            _loadRecentFiles();
          },
        ),
        _buildVibrantToolCard(
          title: 'Scan Mode',
          subtitle: 'Camera scan',
          icon: Icons.document_scanner_rounded,
          gradient: AppColors.emeraldCyanGradient,
          glowColor: AppColors.neonEmerald,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanModeScreen()),
            );
            _loadRecentFiles();
          },
        ),
        _buildVibrantToolCard(
          title: 'PDF to Images',
          subtitle: 'Extract JPG/PNG',
          icon: Icons.collections_rounded,
          gradient: AppColors.cyanVioletGradient,
          glowColor: AppColors.secondary,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PdfToImagesScreen()),
            );
            _loadRecentFiles();
          },
        ),
        _buildVibrantToolCard(
          title: 'Batch Processing',
          subtitle: 'Bulk operations',
          icon: Icons.bolt_rounded,
          gradient: AppColors.pinkOrangeGradient,
          glowColor: AppColors.primary,
          isDark: isDark,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BatchProcessingScreen()),
            );
            _loadRecentFiles();
          },
        ),
        _buildVibrantToolCard(
          title: 'Export Settings',
          subtitle: 'Folder & pattern',
          icon: Icons.folder_special_rounded,
          gradient: AppColors.amberOrangeGradient,
          glowColor: AppColors.tertiary,
          isDark: isDark,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ExportSettingsScreen()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVibrantToolCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required Color glowColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? glowColor.withValues(alpha: 0.22)
              : glowColor.withValues(alpha: 0.35),
          width: 1.3,
        ),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: isDark ? 0.08 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          splashColor: glowColor.withValues(alpha: 0.15),
          highlightColor: glowColor.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: gradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppColors.neonGlow(glowColor,
                            opacity: 0.35, blur: 10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.sora(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentSection(BuildContext context, bool isDark) {
    if (_loadingRecent) {
      return const SizedBox(
        height: 120,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    if (_recentFiles.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.2,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceContainerDark
                    : AppColors.surfaceContainerLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_rounded,
                size: 28,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No documents generated yet',
              style: GoogleFonts.sora(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Your converted PDFs and merges will appear here.',
              style: GoogleFonts.sora(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _handlePhotoPicking,
              icon: const Icon(Icons.add_photo_alternate_rounded),
              label: const Text('Create your first PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _recentFiles.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = _recentFiles[index];
          return _buildRecentCard(context, item, isDark);
        },
      ),
    );
  }

  Widget _buildRecentCard(
      BuildContext context, HistoryItem item, bool isDark) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => FileUtils.openPdf(item.filePath),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.picture_as_pdf_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.share_outlined, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      onPressed: () => FileUtils.sharePdf(item.filePath),
                      tooltip: 'Share',
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sora(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.surfaceContainerDark
                                : AppColors.surfaceContainerLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            FileUtils.formatBytes(item.fileSizeBytes),
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${item.pageCount} ${item.pageCount == 1 ? 'page' : 'pages'}',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
