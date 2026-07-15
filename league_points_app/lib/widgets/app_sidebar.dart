import 'package:flutter/material.dart';

class SidebarItem {
  const SidebarItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// A collapsible vertical navigation sidebar. The toggle at the bottom
/// switches between an icon-only rail and icons with labels, animating the
/// width so the transition feels fluid rather than an abrupt resize.
class AppSidebar extends StatefulWidget {
  const AppSidebar({super.key, required this.items});

  final List<SidebarItem> items;

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  static const _collapsedWidth = 72.0;
  static const _expandedWidth = 220.0;
  static const _duration = Duration(milliseconds: 220);

  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: _duration,
      curve: Curves.easeInOutCubic,
      width: _expanded ? _expandedWidth : _collapsedWidth,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final item in widget.items) _buildRow(context, icon: item.icon, label: item.label, onTap: item.onTap),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildRow(
            context,
            icon: _expanded ? Icons.chevron_left : Icons.chevron_right,
            label: 'Collapse',
            onTap: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: _expanded ? '' : label,
      waitDuration: const Duration(milliseconds: 400),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 24),
                Icon(icon),
                const SizedBox(width: 16),
                Expanded(
                  child: AnimatedOpacity(
                    duration: _duration,
                    opacity: _expanded ? 1 : 0,
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
