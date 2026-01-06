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
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          border: Border(
            right: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
            // 分类标题
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.category, color: Colors.white70),
                  SizedBox(width: 12),
                  Text(
                    '分类',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            // 分类列表
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final isSelected = category == selectedCategory;
                  return CategoryListItem(
                    title: category,
                    isSelected: isSelected,
                    onCategorySelected: () => onCategorySelected(category),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryListItem extends StatefulWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onCategorySelected;

  const CategoryListItem({
    super.key,
    required this.title,
    required this.isSelected,
    required this.onCategorySelected,
  });

  @override
  State<CategoryListItem> createState() => _CategoryListItemState();
}

class _CategoryListItemState extends State<CategoryListItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onCategorySelected,
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });
        // ✅ 焦点改变时更新频道列表（但不自动跳转到频道）
        if (hasFocus) {
          widget.onCategorySelected();
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: _isFocused
              ? Colors.blue.withOpacity(0.3)
              : widget.isSelected
              ? Colors.blue.withOpacity(0.1)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: widget.isSelected ? Colors.blue : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Row(
          children: [
            // 选中指示器
            if (widget.isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.blue,
                size: 20,
              )
            else
              const SizedBox(width: 20),
            const SizedBox(width: 12),
            // 分类名称
            Expanded(
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: widget.isSelected || _isFocused
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: widget.isSelected
                      ? Colors.blue.shade300
                      : _isFocused
                      ? Colors.white
                      : Colors.white70,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}