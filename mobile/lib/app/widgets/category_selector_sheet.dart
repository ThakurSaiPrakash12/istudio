import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../utils/photographer_categories.dart';
import 'studio_button.dart';

class CategorySelectorSheet extends StatefulWidget {
  const CategorySelectorSheet({
    super.key,
    required this.selected,
    required this.onChanged,
    this.title = 'Select Photographer Roles & Categories',
    this.subtitle = 'Choose multiple roles that define your studio and services',
    this.isEmbedded = false,
  });

  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final String title;
  final String subtitle;
  final bool isEmbedded;

  static Future<List<String>?> show(
    BuildContext context, {
    required List<String> initial,
  }) {
    List<String> current = List<String>.from(initial);
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: ctx.cardBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: CategorySelectorSheet(
            selected: current,
            onChanged: (updated) => current = updated,
          ),
        );
      },
    );
  }

  @override
  State<CategorySelectorSheet> createState() => _CategorySelectorSheetState();
}

class _CategorySelectorSheetState extends State<CategorySelectorSheet> {
  late final Set<String> _selected;
  final TextEditingController _customController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _selected = Set<String>.from(widget.selected);
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _toggle(String category) {
    setState(() {
      if (_selected.contains(category)) {
        _selected.remove(category);
      } else {
        _selected.add(category);
      }
    });
    widget.onChanged(_selected.toList());
  }

  void _addCustomCategory() {
    final text = _customController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _selected.add(text);
        _customController.clear();
        _showCustomInput = false;
      });
      widget.onChanged(_selected.toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isEmbedded ? 0 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!widget.isEmbedded) ...[
            Center(
              child: Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: context.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: context.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: Icon(Icons.close_rounded, color: context.textMuted),
                  onPressed: () => Navigator.of(context).pop(_selected.toList()),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Selected count badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.sky.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.sky.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: AppColors.sky,
                ),
                const SizedBox(width: 6),
                Text(
                  '${_selected.length} Selected (Multiple Allowed)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.sky,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Primary Roles
          _buildSectionHeader('Primary Roles', Icons.camera_alt_outlined),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: PhotographerCategories.primaryRoles
                .map((role) => _buildChip(role))
                .toList(),
          ),
          const SizedBox(height: 20),

          // Operators
          _buildSectionHeader('Operators', Icons.video_camera_back_outlined),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...PhotographerCategories.formattedOperatorRoles
                  .map((role) => _buildChip(role)),
              ...PhotographerCategories.operatorRoles
                  .where((op) => !PhotographerCategories.formattedOperatorRoles.contains('Operators: $op'))
                  .map((role) => _buildChip(role)),
            ],
          ),
          const SizedBox(height: 20),

          // Others and Custom
          _buildSectionHeader('Others & Custom Roles', Icons.more_horiz_rounded),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(PhotographerCategories.otherCategory),
              // Show any custom tags that were added
              ..._selected
                  .where((c) =>
                      !PhotographerCategories.primaryRoles.contains(c) &&
                      !PhotographerCategories.formattedOperatorRoles.contains(c) &&
                      !PhotographerCategories.operatorRoles.contains(c) &&
                      c != PhotographerCategories.otherCategory)
                  .map((c) => _buildChip(c, isCustom: true)),
            ],
          ),
          const SizedBox(height: 12),

          if (!_showCustomInput)
            TextButton.icon(
              onPressed: () => setState(() => _showCustomInput = true),
              icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.sky),
              label: Text(
                'Add custom role or category',
                style: GoogleFonts.plusJakartaSans(
                  color: AppColors.sky,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Pre-wedding specialist',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: context.textMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: context.innerBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: context.cardBorder),
                      ),
                    ),
                    onSubmitted: (_) => _addCustomCategory(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Add',
                  onPressed: _addCustomCategory,
                  icon: const Icon(Icons.check_circle_rounded, color: AppColors.sky),
                ),
                IconButton(
                  tooltip: 'Cancel',
                  onPressed: () => setState(() => _showCustomInput = false),
                  icon: Icon(Icons.close_rounded, color: context.textMuted),
                ),
              ],
            ),

          if (!widget.isEmbedded) ...[
            const SizedBox(height: 24),
            StudioButton(
              label: 'Done (${_selected.length} Selected)',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.of(context).pop(_selected.toList()),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: context.textMuted),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.textMuted,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildChip(String label, {bool isCustom = false}) {
    final isSelected = _selected.contains(label);
    final isDark = context.isDark;

    return FilterChip(
      selected: isSelected,
      showCheckmark: true,
      checkmarkColor: Colors.white,
      avatar: isCustom
          ? const Icon(Icons.star_border_rounded, size: 14, color: AppColors.sky)
          : null,
      label: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          color: isSelected ? Colors.white : context.textMain,
        ),
      ),
      selectedColor: AppColors.sky,
      backgroundColor: isDark
          ? const Color(0xFF1E2433)
          : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected
            ? AppColors.sky
            : (isDark
                ? const Color(0xFF2E384D)
                : const Color(0xFFE2E8F0)),
        width: 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (_) => _toggle(label),
    );
  }
}
