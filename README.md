#### drag_anim
# 自动检测位置变化进行位移动画

```yaml
dependencies:
  ...
  drag_anim: <latest_version>
```

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

![Staired example][aligned_example]

<!-- Links -->
[aligned_example]: https://raw.githubusercontent.com/letsar/drag_anim/master/docs/images/123.mp4