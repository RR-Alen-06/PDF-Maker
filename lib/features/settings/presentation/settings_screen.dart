import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_maker/features/settings/presentation/about_legal_screen.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/features/settings/services/settings_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.sora(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Row(
            children: [
              const Icon(Icons.palette_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'APPEARANCE & THEME',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                _buildRadioTile(
                  title: 'System Default',
                  subtitle: 'Match device light/dark setting',
                  value: ThemeMode.system,
                  groupValue: themeMode,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(val);
                    }
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                _buildRadioTile(
                  title: 'Light Mode',
                  subtitle: 'Crisp vibrant lavender surfaces',
                  value: ThemeMode.light,
                  groupValue: themeMode,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(val);
                    }
                  },
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                _buildRadioTile(
                  title: 'Dark Mode (Cyberpunk)',
                  subtitle: 'Deep violet with neon glowing accents',
                  value: ThemeMode.dark,
                  groupValue: themeMode,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(themeModeProvider.notifier).setThemeMode(val);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Icon(Icons.document_scanner_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'OCR & DOCUMENT INTELLIGENCE',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                width: 1.2,
              ),
            ),
            child: FutureBuilder<bool>(
              future: SharedPreferences.getInstance().then((p) => p.getBool('enable_ocr_searchable_pdf') ?? false),
              builder: (context, snapshot) {
                final ocrEnabled = snapshot.data ?? false;
                return SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    'Make PDF Searchable (OCR)',
                    style: GoogleFonts.sora(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    'Run on-device text recognition to add searchable text layers.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  value: ocrEnabled,
                  onChanged: (val) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('enable_ocr_searchable_pdf', val);
                    (context as Element).markNeedsBuild();
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 18, color: AppColors.secondary),
              const SizedBox(width: 8),
              Text(
                'SECURITY & PRIVACY',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.neonEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: AppColors.neonEmerald, size: 20),
                  ),
                  title: Text(
                    '100% Offline Processing',
                    style: GoogleFonts.sora(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(
                    'No documents or images leave your device.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.high_quality_rounded,
                        color: AppColors.secondary, size: 20),
                  ),
                  title: Text(
                    'Default PDF Quality',
                    style: GoogleFonts.sora(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text('Default image compression level for new documents', style: TextStyle(fontSize: 12)),
                  trailing: FutureBuilder<String>(
                    future: SharedPreferences.getInstance().then((p) => p.getString('default_pdf_quality') ?? 'Balanced'),
                    builder: (context, snapshot) {
                      final current = snapshot.data ?? 'Balanced';
                      return DropdownButton<String>(
                        value: current,
                        underline: const SizedBox(),
                        items: ['Draft (72 DPI)', 'Balanced (150 DPI)', 'High (220 DPI)', 'Ultra HD (300 DPI)'].map((q) {
                          final key = q.split(' ').first;
                          return DropdownMenuItem(value: key, child: Text(q, style: const TextStyle(fontSize: 12)));
                        }).toList(),
                        onChanged: (val) async {
                          if (val != null) {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('default_pdf_quality', val);
                            (context as Element).markNeedsBuild();
                          }
                        },
                      );
                    },
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.info_outline_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  title: Text(
                    'About & Open-Source Licenses',
                    style: GoogleFonts.sora(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: const Text('Version, legal attribution & package licenses', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutLegalScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required ThemeMode value,
    required ThemeMode groupValue,
    required ValueChanged<ThemeMode?> onChanged,
  }) {
    final isSelected = value == groupValue;
    return ListTile(
      title: Text(
        title,
        style: GoogleFonts.sora(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 14,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: isSelected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
          : const Icon(Icons.radio_button_unchecked_rounded, color: Colors.grey, size: 22),
      onTap: () => onChanged(value),
    );
  }
}
