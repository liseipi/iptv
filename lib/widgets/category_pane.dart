// lib/widgets/category_pane.dart (优化版 - 修复焦点显示问题)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CategoryPane extends StatelessWidget {
  final FocusScopeNode focusScopeNode;
  final ScrollController scrollController;
  final List<String> categories;
  final String selectedCategory;
  // 🎯 修改回调签名，支持传递 shouldResetChannel 参数
  final Function(String category, {bool shouldResetChannel}) onCategorySelected;

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
                    // 🎯 第一个分类默认获得焦点
                    autofocus: index == 0,
                    onCategorySelected: onCategorySelected,
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
  final bool autofocus;
  // 🎯 修改回调签名
  final Function(String category, {bool shouldResetChannel}) onCategorySelected;

  const CategoryListItem({
    super.key,
    required this.title,
    required this.isSelected,
    this.autofocus = false,
    required this.onCategorySelected,
  });

  @override
  State<CategoryListItem> createState() => _CategoryListItemState();
}

class _CategoryListItemState extends State<CategoryListItem> {
  bool _isFocused = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onFocusChange: (hasFocus) {
        setState(() {
          _isFocused = hasFocus;
        });

        // 🎯 关键修复: 焦点改变时，不重置频道（保持当前频道）
        if (hasFocus) {
          widget.onCategorySelected(widget.title, shouldResetChannel: false);
          Scrollable.ensureVisible(
            context,
            alignment: 0.5,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      onKey: (node, event) {
        // 🎯 新增: 捕获上下键，表示用户在切换分类
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            // 上下键切换时，延迟触发重置（等待焦点切换完成）
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted && _isFocused) {
                // 此时焦点已经在新的分类项上，需要重置频道
                widget.onCategorySelected(widget.title, shouldResetChannel: true);
              }
            });
          }
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: () {
          // 🎯 点击时也重置频道
          widget.onCategorySelected(widget.title, shouldResetChannel: true);
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
      ),
    );
  }
}