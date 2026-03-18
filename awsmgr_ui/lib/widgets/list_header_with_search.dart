import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ListHeaderWithSearch extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? svgAsset;
  final Color iconBackgroundColor;
  final Color iconColor;
  final TextEditingController? searchController;
  final FocusNode? searchFocusNode;
  final String searchHint;
  final bool showSearch;
  final Color? headerBackgroundColor;
  final Widget? actionWidget;

  const ListHeaderWithSearch({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.svgAsset,
    required this.iconBackgroundColor,
    required this.iconColor,
    this.searchController,
    this.searchFocusNode,
    this.searchHint = 'Search...',
    this.showSearch = true,
    this.headerBackgroundColor,
    this.actionWidget,
  }) : assert(
         icon != null || svgAsset != null,
         'Either icon or svgAsset must be provided',
       );

  @override
  State<ListHeaderWithSearch> createState() => _ListHeaderWithSearchState();
}

class _ListHeaderWithSearchState extends State<ListHeaderWithSearch>
    with SingleTickerProviderStateMixin {
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _searchAnimationController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchExpanded = !_searchExpanded;
      if (!_searchExpanded) {
        _searchAnimationController.reverse();
        widget.searchController?.clear();
        widget.searchFocusNode?.unfocus();
      } else {
        _searchAnimationController.forward();
        widget.searchFocusNode?.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color:
            widget.headerBackgroundColor ??
            (isDark
                ? widget.iconColor.withValues(alpha: 0.15)
                : widget.iconColor.withValues(alpha: 0.1)),
        border: Border(
          bottom: BorderSide(
            color: widget.iconColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.iconBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: widget.svgAsset != null
                    ? SvgPicture.asset(widget.svgAsset!, width: 22, height: 22)
                    : Icon(widget.icon!, color: widget.iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              if (!_searchExpanded)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          widget.subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_searchExpanded &&
                  widget.showSearch &&
                  widget.searchController != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextField(
                      controller: widget.searchController,
                      focusNode: widget.searchFocusNode,
                      autofocus: true,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: widget.iconColor,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        hintStyle: TextStyle(
                          color: isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: theme.cardColor,
                      ),
                    ),
                  ),
                ),
              if (!_searchExpanded) const SizedBox(width: 12),
              if (widget.showSearch && widget.searchController != null)
                IconButton(
                  icon: Icon(
                    _searchExpanded ? Icons.close : Icons.search,
                    color: widget.iconColor,
                  ),
                  onPressed: _toggleSearch,
                  style: IconButton.styleFrom(
                    backgroundColor: theme.cardColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                )
              else if (widget.actionWidget != null)
                widget.actionWidget!,
            ],
          ),
        ],
      ),
    );
  }
}
