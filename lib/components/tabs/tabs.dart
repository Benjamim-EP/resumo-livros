// lib/components/tabs/tabs.dart
import 'package:flutter/material.dart';

class Tabs extends StatefulWidget {
  final List<String> tabs;
  final Function(String) onTabSelected;
  final String selectedTab;

  const Tabs({
    super.key,
    required this.tabs,
    required this.onTabSelected,
    required this.selectedTab,
  });

  @override
  State<Tabs> createState() => _TabsState();
}

class _TabsState extends State<Tabs> {
  final List<GlobalKey> _tabKeys = [];
  double _indicatorX = 0.0;
  double _indicatorWidth = 0.0;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.tabs.length; i++) {
      _tabKeys.add(GlobalKey());
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateIndicatorPosition());
  }

  @override
  void didUpdateWidget(covariant Tabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedTab != oldWidget.selectedTab) {
      _updateIndicatorPosition();
    }
  }

  void _updateIndicatorPosition() {
    final int selectedIndex = widget.tabs.indexOf(widget.selectedTab);
    if (selectedIndex == -1 || selectedIndex >= _tabKeys.length) return;

    final GlobalKey selectedKey = _tabKeys[selectedIndex];
    final RenderBox? renderBox =
        selectedKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final size = renderBox.size;
      final position = renderBox.localToGlobal(Offset.zero);
      final parentRenderBox = context.findRenderObject() as RenderBox;
      final relativePosition = parentRenderBox.globalToLocal(position);

      setState(() {
        _indicatorX = relativePosition.dx;
        _indicatorWidth = size.width;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
              color: theme.dividerColor.withOpacity(0.2), width: 1.5),
        ),
      ),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            left: _indicatorX,
            bottom: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              width: _indicatorWidth,
              height: 3.0,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(widget.tabs.length, (index) {
              final label = widget.tabs[index];
              final isSelected = widget.selectedTab == label;

              // Define o estilo do texto com base na seleção
              final textStyle = TextStyle(
                fontSize: 15,
                color: isSelected
                    ? theme.textTheme.bodyLarge?.color
                    : theme.textTheme.bodyLarge?.color?.withOpacity(0.6),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              );

              return Expanded(
                child: GestureDetector(
                  key: _tabKeys[index],
                  onTap: () {
                    if (!isSelected) {
                      widget.onTabSelected(label);
                    }
                  },
                  behavior: HitTestBehavior.translucent,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14.0),
                    child: AnimatedDefaultTextStyle(
                      // ✅ ESTA É A CORREÇÃO PRINCIPAL
                      // Este widget animará automaticamente as mudanças no estilo.
                      style: textStyle,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
