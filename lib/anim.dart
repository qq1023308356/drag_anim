import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'drag_anim_notification.dart';

class DragAnimWidget extends ImplicitlyAnimatedWidget {
  const DragAnimWidget({
    required this.child,
    Duration? duration,
    this.onAnimationStatus,
    Key? key,
  }) : super(key: key, duration: duration ?? _animDuration);
  final Widget child;
  final AnimationStatusListener? onAnimationStatus;
  static const Duration _animDuration = Duration(milliseconds: 200);

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState() => _DragAnimWidgetState();
}

class _DragAnimWidgetState extends AnimatedWidgetBaseState<DragAnimWidget> {
  RenderAnimManage renderAnimManage = RenderAnimManage();

  @override
  void initState() {
    super.initState();
    renderAnimManage.controller = controller;
    renderAnimManage.animation = animation;
    if (widget.onAnimationStatus != null) {
      controller.addStatusListener(widget.onAnimationStatus!);
    }
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {}

  void update() {
    controller
      ..value = 0.0
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    return _DragAnimRender(
      renderAnimManage,
      animation.value,
      change: () {
        SchedulerBinding.instance?.addPostFrameCallback((_) {
          update();
        });
      },
      child: widget.child,
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
    return _AnimRenderObject(renderAnimManage, update, change: change);
  }

  @override
  void updateRenderObject(BuildContext context, _AnimRenderObject renderObject) {
    if (isExecute && renderObject.update != update) {
      renderObject.markNeedsLayout();
    }
  }
}

class _AnimRenderObject extends RenderShiftedBox {
  _AnimRenderObject(
    this.renderAnimManage,
    this.update, {
    RenderBox? child,
    this.change,
  }) : super(child);
  final void Function()? change;
  final RenderAnimManage renderAnimManage;
  final double update;

  Offset? lastOffset;

  bool get isExecute => !DragAnimNotification.isScroll;

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
    size = constraints.constrain(Size(
      child!.size.width,
      child!.size.height,
    ));
  }

  void setStart(EdgeInsetsGeometry? begin, EdgeInsetsGeometry? end) {
    renderAnimManage.tweenOffset = EdgeInsetsGeometryTween(begin: begin, end: end);
    change?.call();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      final BoxParentData childParentData = child!.parentData! as BoxParentData;
      final Offset position = childParentData.offset + offset;
      renderAnimManage.currentOffset ??= EdgeInsets.only(left: position.dx, top: position.dy);
      if (renderAnimManage.controller.isAnimating && renderAnimManage.tweenOffset != null) {
        final EdgeInsets geometry = renderAnimManage.tweenOffset!.evaluate(renderAnimManage.animation) as EdgeInsets;
        context.paintChild(child!, Offset(geometry.left, geometry.top));
        if (renderAnimManage.currentOffset!.left != position.dx || renderAnimManage.currentOffset!.top != position.dy) {
          //log("执行中再次改变动画 ${renderAnimManage.currentOffset}  $position");
          setStart(geometry, EdgeInsets.only(left: position.dx, top: position.dy));
        }
        renderAnimManage.currentOffset = EdgeInsets.only(left: position.dx, top: position.dy);
      } else {
        if (isExecute &&
            renderAnimManage.currentOffset != null &&
            (renderAnimManage.currentOffset!.left != position.dx ||
                renderAnimManage.currentOffset!.top != position.dy)) {
          //log("开始 ${renderAnimManage.currentOffset}  $position");
          context.paintChild(child!, Offset(renderAnimManage.currentOffset!.left, renderAnimManage.currentOffset!.top));
          setStart(renderAnimManage.currentOffset, EdgeInsets.only(left: position.dx, top: position.dy));
          renderAnimManage.currentOffset = EdgeInsets.only(left: position.dx, top: position.dy);
        } else {
          renderAnimManage.currentOffset = EdgeInsets.only(left: position.dx, top: position.dy);

          //log("正常 $position");
          context.paintChild(child!, position);
        }
      }
    }
  }
}

class RenderAnimManage {
  RenderAnimManage();
  EdgeInsetsGeometryTween? tweenOffset;
  EdgeInsets? currentOffset;
  late AnimationController controller;
  late Animation<double> animation;
}
