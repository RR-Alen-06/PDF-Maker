import 'package:flutter/material.dart';
import 'package:pdf_maker/core/constants/app_colors.dart';
import 'package:pdf_maker/core/constants/page_sizes.dart';

class LayoutSelector extends StatelessWidget {
  final PdfPhotoLayout selectedLayout;
  final ValueChanged<PdfPhotoLayout> onLayoutSelected;

  const LayoutSelector({
    super.key,
    required this.selectedLayout,
    required this.onLayoutSelected,
  });

  IconData _getLayoutIcon(PdfPhotoLayout layout) {
    switch (layout) {
      case PdfPhotoLayout.onePerPage:
        return Icons.crop_portrait_rounded;
      case PdfPhotoLayout.twoPerPageStacked:
        return Icons.view_agenda_rounded;
      case PdfPhotoLayout.twoPerPageSideBySide:
        return Icons.view_column_rounded;
      case PdfPhotoLayout.threePerPage:
        return Icons.view_stream_rounded;
      case PdfPhotoLayout.fourPerPageGrid:
        return Icons.grid_view_rounded;
      case PdfPhotoLayout.sixPerPageGrid:
        return Icons.apps_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: PdfPhotoLayout.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final layout = PdfPhotoLayout.values[index];
          final isSelected = layout == selectedLayout;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onLayoutSelected(layout),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Theme.of(context).dividerColor.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getLayoutIcon(layout),
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      layout.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
