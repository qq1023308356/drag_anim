import 'package:drag_anim/widget/drag_anim_notification.dart';
import 'package:drag_anim/widget/render_anim_manage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

class DragAnimWidget<T> extends StatefulWidget {
  const DragAnimWidget(
      {required this.child,
      required this.controller,
      required this.contextOffset,
      this.isExecuteAnimation,
      this.didAndChange,
      Duration? duration,
      Key? key})
      : super(key: key);
  final Widget child;
  final AnimationController controller;
  final Function(BuildContext context, bool isDispose)? didAndChange;
  final ContextOffset? Function()? contextOffset;
  final bool Function()? isExecuteAnimation;

  @override
  State<StatefulWidget> createState() => _DragAnimWidgetState();
}

class _DragAnimWidgetState extends State<DragAnimWidget> {
  late RenderAnimManage renderAnimManage = RenderAnimManage(
    widget.contextOffset,
    isExecuteAnimation: widget.isExecuteAnimation,
  );

  @override
  void initState() {
    super.initState();
    renderAnimManage.controller = widget.controller;
    widget.didAndChange?.call(context, false);
  }

  @override
  void dispose() {
    widget.didAndChange?.call(context, true);
    super.dispose();
  }

  void update() {
    if (!widget.controller.isAnimating) {
      widget.controller.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        return _DragAnimRender(
          key: widget.key,
          renderAnimManage,
          widget.controller.value,
          change: () {
            SchedulerBinding.instance.addPostFrameCallback((_) {
              update();
            });
          },
          child: widget.child,
        );
      },
    );
  }
}

class _DragAnimRender extends SingleChildRenderObjectWidget {
  const _DragAnimRender(
    this.renderAnimManage,
    this.update, {
    Key? key,
    Widget? child,
    this.change,
  }) : super(key: key, child: child);
  final void Function()? change;
  final RenderAnimManage renderAnimManage;
  final double update;

  bool get isExecute => !DragAnimNotification.isScroll;

  @override
  _AnimRenderObject createRenderObject(BuildContext context) {
    return _AnimRenderObject(renderAnimManage, update, key: key, change: change);
  }

  @override
  void updateRenderObject(BuildContext context, _AnimRenderObject renderObject) {
    renderObject.update = update;
  }
}

class _AnimRenderObject extends RenderShiftedBox {
  _AnimRenderObject(this.renderAnimManage, double? update, {RenderBox? child, this.key, this.change})
      : _update = update,
        super(child);
  final void Function()? change;
  final RenderAnimManage renderAnimManage;
  final Key? key;

  double? _update;

  bool get isExecute => !DragAnimNotification.isScroll;

  double? get update => _update;

  set update(double? value) {
    if (renderAnimManage.controller.isCompleted) {
      renderAnimManage.tweenOffset = null;
    }
    if (_update == value) {
      return;
    }
    _update = value;
    markNeedsLayout();
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    if (child == null) {
      return constraints.constrain(const Size(0, 0));
    }

    final BoxConstraints innerConstraints = constraints.deflate(EdgeInsets.zero);
    final Size childSize = child!.getDryLayout(innerConstraints);
    return constraints.constrain(Size(childSize.width, childSize.height));
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    if (child == null) {
      size = constraints.constrain(const Size(0, 0));
      return;
    }
    final BoxConstraints innerConstraints = constraints.deflate(EdgeInsets.zero);
    child!.layout(innerConstraints, parentUsesSize: true);
    final BoxParentData childParentData = child!.parentData! as BoxParentData;
    childParentData.offset = const Offset(0, 0);
    size = constraints.constrain(Size(child!.size.width, child!.size.height));
  }

  void setStart(Offset begin, Offset end) {
    renderAnimManage.tweenOffset = Tween<Offset>(begin: begin, end: end);
    change?.call();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final RenderBox? child = this.child;
    if (child != null) {
      final BoxParentData childParentData = child.parentData as BoxParentData;
      final Offset parentPosition = childParentData.offset + offset;
      var localOffset = child.localToGlobal(Offset.zero); // 转换为屏幕坐标
      if (renderAnimManage.isExecuteAnimation?.call() == false) {
        renderAnimManage.lastOffset = localOffset;
        context.paintChild(child, parentPosition);
        return;
      }
      final Offset? lastOffset = renderAnimManage.lastOffset;
      final Tween<Offset>? tweenOffset = renderAnimManage.tweenOffset;
      if (isExecute && tweenOffset != null) {
        final Offset geometry = tweenOffset.evaluate(renderAnimManage.controller);
        //print("执行 ${key}  $geometry  $tweenOffset  ${renderAnimManage.controller}");
        context.paintChild(child, geometry);
      } else {
        if (isExecute && lastOffset != null && lastOffset != localOffset) {
          Offset startOffset = lastOffset - localOffset + parentPosition;
          context.paintChild(child, startOffset);
          setStart(startOffset, parentPosition);
          //print("开始 ${key} ${renderAnimManage.tweenOffset}  $startOffset  $parentPosition");
        } else {
          //print("正常 ${key}  $localOffset  $parentPosition");
          renderAnimManage.tweenOffset = null;
          renderAnimManage.lastOffset = localOffset;
          context.paintChild(child, parentPosition);
        }
      }
    }
  }
}
