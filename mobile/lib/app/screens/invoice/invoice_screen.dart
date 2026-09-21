import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../widgets/monthly_financial_summary_sheet.dart';
import '../../widgets/studio_app_bar.dart';
import 'create_invoice_form.dart';
import 'invoice_history_tab.dart';

class InvoiceScreen extends StatefulWidget {
  const InvoiceScreen({super.key});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  bool _isCreate = true;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            children: [
              StudioAppBar(
                title: 'Receipt',
                subtitle: _isCreate
                    ? 'Make a bill'
                    : 'All bills',
                actions: [
                  IconButton(
                    tooltip: 'Summary',
                    icon: Icon(
                      Icons.insights_rounded,
                      color: context.accentColor,
                      size: 22,
                    ),
                    onPressed: () => MonthlyFinancialSummarySheet.show(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: _InvoiceModeToggle(
                  isCreate: _isCreate,
                  onChanged: (value) => setState(() => _isCreate = value),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: _isCreate
                      ? KeyedSubtree(
                          key: const ValueKey('invoice_create'),
                          child: CreateInvoiceForm(
                            onSaved: (_) => setState(() => _isCreate = false),
                          ),
                        )
                      : const KeyedSubtree(
                          key: ValueKey('invoice_history'),
                          child: InvoiceHistoryTab(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _InvoiceModeToggle extends StatelessWidget {
  const _InvoiceModeToggle({
    required this.isCreate,
    required this.onChanged,
  });

  final bool isCreate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Semantics(
      label: isCreate ? 'New selected' : 'Past selected',
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: isDark ? AppColors.glassInnerDark : AppColors.glassInnerLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
            width: 1.2,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final tabWidth = (constraints.maxWidth - 4) / 2;
            return Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutBack,
                  alignment: isCreate
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    width: tabWidth,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: isDark
                          ? AppColors.skyGradient
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF7B3FE4), Color(0xFF5F259F)],
                            ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.sky.withValues(alpha: isDark ? 0.35 : 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    _Tab(
                      label: 'New',
                      selected: isCreate,
                      onTap: () => onChanged(true),
                    ),
                    _Tab(
                      label: 'Past',
                      selected: !isCreate,
                      onTap: () => onChanged(false),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : context.textMuted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
              child: Text(label),
            ),
          ),
        ),
      ),
    );
  }
}

