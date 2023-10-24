import 'package:flutter/material.dart';

class RenderBoxSize extends StatefulWidget {
  const RenderBoxSize(this.child, this.onChangeSize, {Key? key}) : super(key: key);

  final Widget child;
  final void Function(Size size) onChangeSize;

  @override
  State<StatefulWidget> createState() => RenderBoxSizeState();
}

class RenderBoxSizeState extends State<RenderBoxSize> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration timeStamp) {
      onChangeSize();
    });
  }

  void onChangeSize() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      widget.onChangeSize(renderBox.size);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SizeChangedLayoutNotification>(
        onNotification: (SizeChangedLayoutNotification notification) {
          onChangeSize();
          return true;
        },
        child: widget.child);
  }
}
