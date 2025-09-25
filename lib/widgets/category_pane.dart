// lib/widgets/category_pane.dart
import 'package:flutter/material.dart';

class CategoryPane extends StatelessWidget {
  final FocusScopeNode focusScopeNode;
  final ScrollController scrollController;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  const CategoryPane({
    super.key,
    required this.focusScopeNode,
    required this.scrollController,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: focusScopeNode,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: ListView.builder(
          controller: scrollController,
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = category == selectedCategory;
            return CategoryListItem(
              title: category,
              isSelected: isSelected,
              onTap: () => onCategorySelected(category),
            );
          },
        ),
      ),
    );
  }
}

class CategoryListItem extends StatefulWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryListItem({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<CategoryListItem> createState() => _CategoryListItemState();
}

class _CategoryListItemState extends State<CategoryListItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
          // 当获得焦点时，也触发选中
          if (hasFocus) {
            widget.onTap();
            Scrollable.ensureVisible(
              context,
              alignment: 0.5,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        color: _isFocused ? Colors.blue.withOpacity(0.3) : Colors.transparent,
        child: Text(
          widget.title,
          maxLines: 1,
          style: TextStyle(
            fontSize: 22,
            fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
            color: widget.isSelected ? Colors.blue.shade300 : Colors.white,
          ),
        ),
      ),
    );
  }
}