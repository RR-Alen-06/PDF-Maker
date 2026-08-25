import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';

class ReusableTemplate {
  final String id;
  final String name; // max 50 characters
  final PdfExportConfig config;
  final DateTime createdAt;

  const ReusableTemplate({
    required this.id,
    required this.name,
    required this.config,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'config': config.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ReusableTemplate.fromJson(Map<String, dynamic> json) {
    return ReusableTemplate(
      id: json['id'] as String,
      name: json['name'] as String,
      config: PdfExportConfig.fromJson(json['config'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class TemplateStorageService {
  static const _key = 'pdf_maker_saved_templates';

  TemplateStorageService._();

  /// Load all saved reusable templates
  static Future<List<ReusableTemplate>> loadTemplates() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonListStr = prefs.getStringList(_key);
    if (jsonListStr == null) return [];

    final templates = <ReusableTemplate>[];
    for (final itemStr in jsonListStr) {
      try {
        final map = jsonDecode(itemStr) as Map<String, dynamic>;
        templates.add(ReusableTemplate.fromJson(map));
      } catch (_) {}
    }
    return templates;
  }

  /// Save a new template or update existing
  static Future<void> saveTemplate(ReusableTemplate template) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadTemplates();
    current.removeWhere((t) => t.id == template.id);
    current.insert(0, template);

    final encoded = current.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_key, encoded);
  }

  /// Delete a template by ID
  static Future<void> deleteTemplate(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadTemplates();
    current.removeWhere((t) => t.id == id);

    final encoded = current.map((t) => jsonEncode(t.toJson())).toList();
    await prefs.setStringList(_key, encoded);
  }

  /// Rename a template
  static Future<void> renameTemplate(String id, String newName) async {
    final current = await loadTemplates();
    final idx = current.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final updated = ReusableTemplate(
        id: current[idx].id,
        name: newName,
        config: current[idx].config,
        createdAt: current[idx].createdAt,
      );
      await saveTemplate(updated);
    }
  }
}
