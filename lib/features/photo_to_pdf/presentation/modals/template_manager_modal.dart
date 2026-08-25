import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/pdf_export_config.dart';
import 'package:pdf_maker/features/photo_to_pdf/domain/models/reusable_template.dart';

class TemplateManagerModal extends StatefulWidget {
  final PdfExportConfig currentConfig;
  final ValueChanged<PdfExportConfig> onApplyTemplate;

  const TemplateManagerModal({
    super.key,
    required this.currentConfig,
    required this.onApplyTemplate,
  });

  @override
  State<TemplateManagerModal> createState() => _TemplateManagerModalState();
}

class _TemplateManagerModalState extends State<TemplateManagerModal> {
  List<ReusableTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    final list = await TemplateStorageService.loadTemplates();
    setState(() {
      _templates = list;
      _isLoading = false;
    });
  }

  void _showSaveCurrentAsTemplateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Save as Template',
          style: GoogleFonts.sora(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Save your current Page Setup and Overlay settings for reuse:',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLength: 50,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Template Name',
                hintText: 'e.g. Invoice Format, Compact Handout',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final template = ReusableTemplate(
                  id: '${DateTime.now().microsecondsSinceEpoch}',
                  name: name,
                  config: widget.currentConfig,
                  createdAt: DateTime.now(),
                );
                await TemplateStorageService.saveTemplate(template);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadTemplates();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Template "$name" saved!'), backgroundColor: AppColors.success),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRenameTemplateDialog(ReusableTemplate template) {
    final controller = TextEditingController(text: template.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Template'),
        content: TextField(
          controller: controller,
          maxLength: 50,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'New Template Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                await TemplateStorageService.renameTemplate(template.id, name);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadTemplates();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 20, left: 16, right: 16, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bookmark_outline_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Reusable Templates',
                    style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _showSaveCurrentAsTemplateDialog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Save Current Setup as Template'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          ),
          const SizedBox(height: 14),

          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_templates.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                child: Column(
                  children: [
                    Icon(Icons.style_outlined, size: 48, color: isDark ? Colors.white38 : Colors.black26),
                    const SizedBox(height: 12),
                    Text(
                      'No templates yet — configure settings and save a template to reuse them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.white60 : Colors.black54, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _templates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final template = _templates[index];
                  final cfg = template.config;
                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: ListTile(
                      title: Text(
                        template.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      subtitle: Text(
                        '${cfg.pageSizePreset.label} • ${cfg.orientation.label} • ${cfg.layout.label} • Margin ${cfg.marginMm.round()}mm',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            tooltip: 'Rename',
                            onPressed: () => _showRenameTemplateDialog(template),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                            tooltip: 'Delete',
                            onPressed: () async {
                              await TemplateStorageService.deleteTemplate(template.id);
                              _loadTemplates();
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        widget.onApplyTemplate(template.config);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Applied template "${template.name}"'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
