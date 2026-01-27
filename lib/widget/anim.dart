import 'package:drag_anim/widget/drag_anim_notification.dart';
import 'package:drag_anim/widget/render_anim_manage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

class DragAnimWidget<T> extends ImplicitlyAnimatedWidget {
  const DragAnimWidget(
      {required this.child,
      required this.contextOffset,
      this.isExecuteAnimation,
      this.didAndChange,
      Duration? duration,
      this.onAnimationStatus,
      Key? key})
      : super(key: key, duration: duration ?? _animDuration);
  final Widget child;
  final AnimationStatusListener? onAnimationStatus;
  static const Duration _animDuration = Duration(milliseconds: 200);
  final Function(BuildContext context, bool isDispose)? didAndChange;
  final ContextOffset? Function()? contextOffset;
  final bool Function()? isExecuteAnimation;

  @override
  ImplicitlyAnimatedWidgetState<ImplicitlyAnimatedWidget> createState() => _DragAnimWidgetState();
}

class _DragAnimWidgetState extends AnimatedWidgetBaseState<DragAnimWidget> {
  late RenderAnimManage renderAnimManage = RenderAnimManage(
    widget.contextOffset,
    isExecuteAnimation: widget.isExecuteAnimation,
  );

  @override
  void initState() {
    super.initState();
    renderAnimManage.controller = controller;
    if (widget.onAnimationStatus != null) {
      controller.addStatusListener(widget.onAnimationStatus!);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.didAndChange?.call(context, false);
      }
    });
  }

  @override
  void dispose() {
    widget.didAndChange?.call(context, true);
    super.dispose();
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
        SchedulerBinding.instance.addPostFrameCallback((_) {
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
    if (renderObject.update != update) {
      renderObject.markNeedsLayout();
    }
  }
}

class _AnimRenderObject extends RenderShiftedBox {
  _AnimRenderObject(this.renderAnimManage, this.update, {RenderBox? child, this.change}) : super(child);
  final void Function()? change;
  final RenderAnimManage renderAnimManage;
  final double update;

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
      renderAnimManage.lastOffset ??= Offset(localOffset.dx, localOffset.dy);
      final Offset? lastOffset = renderAnimManage.lastOffset;
      final Tween<Offset>? tweenOffset = renderAnimManage.tweenOffset;
      if (renderAnimManage.isExecuteAnimation?.call() == false) {
        renderAnimManage.lastOffset = localOffset;
        context.paintChild(child, parentPosition);
        return;
      }
      if (renderAnimManage.controller.isAnimating && isExecute && tweenOffset != null && lastOffset != null) {
        final Offset geometry = tweenOffset.evaluate(renderAnimManage.controller);
        context.paintChild(child, geometry);
        renderAnimManage.lastOffset = localOffset;
      } else {
        if (isExecute && lastOffset != null && (lastOffset.dx != localOffset.dx || lastOffset.dy != localOffset.dy)) {
          Offset startOffset = lastOffset - localOffset + parentPosition;
          context.paintChild(child, startOffset);
          setStart(startOffset, parentPosition);
          //print("开始 ${DragAnimNotification.isScroll}  $startOffset  $parentPosition");
          renderAnimManage.lastOffset = localOffset;
        } else {
          renderAnimManage.lastOffset = localOffset;
          //print("正常 ${DragAnimNotification.isScroll}  $localOffset  $parentPosition");
          context.paintChild(child, parentPosition);
        }
      }
    }
  }
}
