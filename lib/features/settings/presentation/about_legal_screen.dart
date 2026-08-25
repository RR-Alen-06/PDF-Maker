import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';

class AboutLegalScreen extends StatelessWidget {
  const AboutLegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About & Legal'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // App Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.neonGlow(AppColors.primary, opacity: 0.4, blur: 16),
                  ),
                  child: const Center(
                    child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 40),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'PDF Maker Studio',
                  style: GoogleFonts.sora(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.0.0 (Build 1)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Open-Source Licenses section
          Container(
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
                ListTile(
                  leading: const Icon(Icons.source_rounded, color: AppColors.primary),
                  title: Text(
                    'Open-Source Licenses',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text('View third-party package licenses and notices', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'PDF Maker Studio',
                    applicationVersion: 'v1.0.0',
                    applicationLegalese: 'Copyright © 2026 PDF Maker Studio. 100% Offline & Private.',
                  ),
                ),
                Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ListTile(
                  leading: const Icon(Icons.shield_outlined, color: AppColors.secondary),
                  title: Text(
                    'Syncfusion Community License',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Licensed under the Syncfusion Community License for qualifying developers (< \$1M gross revenue & < 5 developers).',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                Divider(height: 1, color: isDark ? AppColors.borderDark : AppColors.borderLight),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded, color: AppColors.neonEmerald),
                  title: Text(
                    '100% Offline Privacy Guarantee',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Zero analytics, zero tracking, zero remote network calls. All document operations execute entirely on your device.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
