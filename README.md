# drag_anim
#### **注意事项**
- 自动检测位置变化进行位移动画，需要widget不会被重新创建根据情况添加key
- 如果滑动组件在buildItems下则可以嵌套DragAnimNotification也可以设置isDragAnimNotification = true
- DragAnim 不是滑动组件的子widget的时候需要传scrollController，不然无法到边缘自动滚动
- 理论支持各种widget，例子是用flutter_staggered_grid_view 进行测试
- 注意需要widget不会被销毁，重新创建


```yaml
dependencies:
  ...
  drag_anim: <latest_version>
```

![Staired example][aligned_example]

```dart
  @override
  Widget build(BuildContext context) {
    return DragAnimNotification(
      child: Center(
        child: Container(
          alignment: Alignment.centerLeft,
          height: 468,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            scrollDirection: Axis.horizontal,
            children: <Widget>[
              DragAnim<HomeEditCard>(
                scrollDirection: Axis.horizontal,
                buildItems: (List<Widget> children) {
                  return StaggeredGrid.count(
                    crossAxisCount: 4,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    children: children,
                  );
                },
                items: (HomeEditCard element, DragItems dragItems) {
                  return StaggeredGridTile.count(
                    key: ValueKey<String>(element.key ?? ''),
                    mainAxisCellCount: element.mainAxisCellCount,
                    crossAxisCellCount: element.crossAxisCellCount,
                    child: dragItems(Container(
                      color: Colors.yellow.withOpacity(0.3),
                    )),
                  );
                },
                buildFeedback: (HomeEditCard data, Widget widget) {
                  return Container(
                    width: 250,
                    height: 250,
                    color: Colors.red,
                  );
                },
                dataList: list,
              ),
            ],
          ),
        ),
      ),
    );
  }
```

<!-- Links -->
[aligned_example]: https://raw.githubusercontent.com/qq1023308356/drag_anim/main/docs/images/123.gif
