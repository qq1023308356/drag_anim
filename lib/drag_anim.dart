import 'dart:async';

import 'package:drag_anim/anim.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // 引入 Scheduler 以使用 Ticker

import 'drag_anim_notification.dart';
import 'render_anim_manage.dart';

typedef DragItems<T> = Widget Function({required T data, required Widget child, required Key key});

class DragAnim<T extends Object> extends StatefulWidget {
  const DragAnim({
    required this.buildItems,
    this.dataList,
    this.isLongPressDraggable = true,
    this.buildFeedback,
    this.axis,
    this.onAcceptWithDetails,
    this.onWillAcceptWithDetails,
    this.onLeave,
    this.onMove,
    this.hitTestBehavior = HitTestBehavior.translucent,
    this.scrollDirection = Axis.vertical,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDraggableCanceled,
    this.onDragEnd,
    this.onDragCompleted,
    this.scrollController,
    this.draggingWidgetOpacity = 0.5,
    this.edgeScroll = 0.06,
    this.scrollSpeed = 1,
    this.isEdgeScroll = true,
    this.isDrag = true,
    this.isNotDragList,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.maxSimultaneousDrags = 1,
    this.longPressDelay,
    this.scrollPosition,
    Key? key,
  }) : super(key: key);
  final Widget Function(DragItems<T>) buildItems;
  final List<T>? dataList;
  final Widget Function(T data, Widget child, Size? size)? buildFeedback;
  final bool isLongPressDraggable;
  final Axis? axis;
  final void Function(DragTargetDetails<T> details, T data)? onAcceptWithDetails;
  final bool Function(DragTargetDetails<T> details, T data, bool isTimer)? onWillAcceptWithDetails;
  final void Function(T? moveData, T data)? onLeave;
  final void Function(T data, DragTargetDetails<T> details)? onMove;
  final Axis scrollDirection;
  final HitTestBehavior hitTestBehavior;
  final void Function(T data)? onDragStarted;
  final void Function(DragUpdateDetails details, T data)? onDragUpdate;
  final void Function(Velocity velocity, Offset offset, T data)? onDraggableCanceled;
  final void Function(DraggableDetails details, T data)? onDragEnd;
  final void Function(T data)? onDragCompleted;
  final ScrollController? scrollController;
  final double draggingWidgetOpacity;
  final double edgeScroll;

  // 表示每秒滚动的百分比
  final double scrollSpeed;
  final bool isDrag;
  final List<T>? isNotDragList;
  final bool isEdgeScroll;
  final DragAnchorStrategy dragAnchorStrategy;
  final int maxSimultaneousDrags;
  final Duration? longPressDelay;
  final ScrollPosition? scrollPosition;

  @override
  State<StatefulWidget> createState() => DragAnimState<T>();
}

// 优化1: 混入 SingleTickerProviderStateMixin 用于创建 Ticker
class DragAnimState<T extends Object> extends State<DragAnim<T>> with SingleTickerProviderStateMixin {
  Timer? _timer;
  Timer? scrollEndTimer;
  ScrollableState? _scrollable;
  AnimationStatus status = AnimationStatus.completed;
  bool isDragStart = false;
  bool isOnWillAccept = false;
  T? dragData;
  final Map<Key, ContextOffset> _contextOffsetMap = {};

  // 优化2: 使用 Ticker 替代 Timer 实现高帧率平滑滚动
  Ticker? _autoScrollTicker;
  double _targetVelocity = 0.0; // 目标速度 (像素/秒)
  Duration _lastTickTime = Duration.zero;

  @override
  void initState() {
    super.initState();
    // 初始化 Ticker，绑定回调
    _autoScrollTicker = createTicker(_onTick);
  }

  // 优化3: Ticker 回调，每一帧执行一次
  void _onTick(Duration elapsed) {
    if (_targetVelocity == 0.0) return;

    final ScrollPosition? position =
        widget.scrollPosition ?? _scrollable?.position ?? widget.scrollController?.position;
    if (position == null) return;

    // 计算上一帧到当前帧的时间差 (秒)
    // elapsed 是从 Ticker 启动开始计算的总时间
    final double deltaTime = (elapsed - _lastTickTime).inMicroseconds / 1000000.0;
    _lastTickTime = elapsed;

    if (deltaTime == 0) return;

    // 计算本帧位移 = 速度 * 时间
    final double deltaPixels = _targetVelocity * deltaTime;
    final double targetPixels = position.pixels + deltaPixels;

    // 边界检查与执行滚动
    if ((_targetVelocity > 0 && position.pixels < position.maxScrollExtent) ||
        (_targetVelocity < 0 && position.pixels > position.minScrollExtent)) {
      // 使用 jumpTo 进行瞬时移动，性能远优于 animateTo
      final double finalPixels = targetPixels.clamp(position.minScrollExtent, position.maxScrollExtent);
      position.jumpTo(finalPixels);
      startScrollEndTimer();
      endWillAccept();
    } else {
      // 到达边界，停止滚动
      endAnimation();
    }
  }

  //重新触发setWillAccept
  void reSetWillAccept() {
    var acceptDetails = this.acceptDetails;
    var acceptData = this.acceptData;
    if (acceptDetails != null && acceptData != null && _timer?.isActive != true) {
      setWillAccept(acceptDetails, acceptData);
    }
  }

  void endWillAccept() {
    _timer?.cancel();
  }

  void setDragStart({bool isDragStart = true}) {
    if (this.isDragStart != isDragStart) {
      setState(() {
        this.isDragStart = isDragStart;
        if (!this.isDragStart) {
          isOnWillAccept = false;
          dragData = null;
        } else {
          endWillAccept();
        }
      });
    }
  }

  void startScrollEndTimer() {
    scrollEndTimer?.cancel();
    scrollEndTimer = Timer(const Duration(milliseconds: 150), () {
      if (!mounted) {
        return;
      }
      updateOffset();
      scrollEndTimer = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DragAnimNotification(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollStartNotification) {
          scrollEndTimer?.cancel();
        } else if (notification is ScrollEndNotification) {
          startScrollEndTimer();
        }
        return false;
      },
      child: widget.buildItems(({required T data, required Widget child, required Key key}) {
        return setDraggable(data: data, father: child, key: key);
      }),
    );
  }

  void updateOffset() {
    _contextOffsetMap.forEach((key, value) {
      value.updateOffset();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.scrollController == null) {
      try {
        _scrollable = Scrollable.of(context);
      } catch (e, s) {
        print('找不到控制器，需要添加 scrollController，$e \n $s');
      }
    }
  }

  //记录setWillAccept的 details data
  DragTargetDetails<T>? acceptDetails;
  T? acceptData;

  bool setWillAccept(DragTargetDetails<T> details, T data) {
    if (details.data == data) return false;
    if (widget.maxSimultaneousDrags == 1 && details.data != dragData) return false;
    // 如果正在执行滚动，逻辑上应该允许在滚动间隙进行排序判定
    if (status == AnimationStatus.completed && scrollEndTimer == null) {
      endWillAccept();
      _timer = Timer(const Duration(milliseconds: 100), () {
        // 缩短排序延迟，增加响应速度
        if (!mounted || DragAnimNotification.isScroll) {
          return;
        }
        acceptDetails = null;
        acceptData = null;
        isOnWillAccept = true;
        if (widget.onWillAcceptWithDetails != null) {
          widget.onWillAcceptWithDetails?.call(details, data, true);
        } else {
          var dataList = widget.dataList;
          if (dataList != null) {
            setState(() {
              final int index = dataList.indexOf(data);
              dataList.remove(details.data);
              dataList.insert(index, details.data);
            });
          }
        }
      });
      return true;
    }
    return false;
  }

  bool isContains(T data) {
    final List<T>? isNotDragList = widget.isNotDragList;
    if (isNotDragList != null) {
      return isNotDragList.contains(data);
    }
    return false;
  }

  Widget setDragScope(T data, Widget child, Key key) {
    final Widget keyWidget = child;
    return DragAnimWidget(
      contextOffset: () => _contextOffsetMap[key],
      isExecuteAnimation: () => isDragStart && isOnWillAccept,
      didAndChange: (BuildContext context, bool isDispose) {
        if (isDispose) {
          _contextOffsetMap.remove(key);
        } else {
          _contextOffsetMap[key] = ContextOffset(context, Offset.zero)..updateOffset();
        }
      },
      key: key,
      child: DragTarget<T>(
        onWillAcceptWithDetails: (DragTargetDetails<T> details) {
          acceptDetails = details;
          acceptData = data;
          if (isDragStart && !DragAnimNotification.isScroll) {
            return setWillAccept(details, data);
          }
          return false;
        },
        onAcceptWithDetails: widget.onAcceptWithDetails == null
            ? null
            : (DragTargetDetails<T> details) => widget.onAcceptWithDetails?.call(details, data),
        onLeave: widget.onLeave == null ? null : (T? moveData) => widget.onLeave?.call(moveData, data),
        onMove: widget.onMove == null ? null : (DragTargetDetails<T> details) => widget.onMove?.call(data, details),
        hitTestBehavior: widget.hitTestBehavior,
        builder: (BuildContext context, List<T?> candidateData, List<dynamic> rejectedData) {
          if (widget.maxSimultaneousDrags == 1 && data != dragData) {
            return keyWidget;
          }
          if (widget.draggingWidgetOpacity > 0 && dragData == data) {
            return AnimatedOpacity(
              opacity: widget.draggingWidgetOpacity,
              duration: Duration(milliseconds: 300),
              child: keyWidget,
            );
          }
          return Visibility(
            child: keyWidget,
            maintainState: true,
            maintainSize: true,
            maintainAnimation: true,
            visible: dragData != data,
          );
        },
      ),
      onAnimationStatus: (AnimationStatus status) {
        if (status.isCompleted) {
          isOnWillAccept = false;
        }
        this.status = status;
      },
    );
  }

  Widget setDraggable({required T data, required Widget father, required Key key}) {
    Widget child = setDragScope(data, father, key);
    int maxSimultaneousDrags = widget.maxSimultaneousDrags;
    if (maxSimultaneousDrags == 1 && dragData != null && dragData != data) {
      maxSimultaneousDrags = 0;
    }
    if (widget.isDrag && !isContains(data)) {
      if (widget.isLongPressDraggable) {
        child = LongPressDraggable<T>(
          feedback: setFeedback(data, father, key),
          maxSimultaneousDrags: maxSimultaneousDrags,
          axis: widget.axis,
          data: data,
          onDragStarted: () {
            if (DragAnimNotification.isScroll) {
              return;
            }
            dragData = data;
            setDragStart();
            widget.onDragStarted?.call(data);
          },
          dragAnchorStrategy: widget.dragAnchorStrategy,
          onDragUpdate: (DragUpdateDetails details) {
            if (widget.isEdgeScroll) {
              _autoScrollIfNecessary(details.globalPosition, father);
            }
            widget.onDragUpdate?.call(details, data);
          },
          onDraggableCanceled: (Velocity velocity, Offset offset) {
            setDragStart(isDragStart: false);
            endAnimation();
            widget.onDraggableCanceled?.call(velocity, offset, data);
          },
          onDragEnd: (DraggableDetails details) {
            setDragStart(isDragStart: false);
            widget.onDragEnd?.call(details, data);
          },
          onDragCompleted: () {
            setDragStart(isDragStart: false);
            endAnimation();
            widget.onDragCompleted?.call(data);
          },
          delay: widget.longPressDelay ?? const Duration(milliseconds: 500),
          child: child,
        );
      } else {
        child = Draggable<T>(
          feedback: setFeedback(data, father, key),
          maxSimultaneousDrags: maxSimultaneousDrags,
          axis: widget.axis,
          data: data,
          onDragStarted: () {
            dragData = data;
            setDragStart();
            widget.onDragStarted?.call(data);
          },
          dragAnchorStrategy: widget.dragAnchorStrategy,
          onDragUpdate: (DragUpdateDetails details) {
            if (widget.isEdgeScroll) {
              _autoScrollIfNecessary(details.globalPosition, father);
            }
            widget.onDragUpdate?.call(details, data);
          },
          onDraggableCanceled: (Velocity velocity, Offset offset) {
            setDragStart(isDragStart: false);
            endAnimation();
            widget.onDraggableCanceled?.call(velocity, offset, data);
          },
          onDragEnd: (DraggableDetails details) {
            setDragStart(isDragStart: false);
            widget.onDragEnd?.call(details, data);
          },
          onDragCompleted: () {
            setDragStart(isDragStart: false);
            endAnimation();
            widget.onDragCompleted?.call(data);
          },
          child: child,
        );
      }
    }
    return child;
  }

  Size? getBoxSize(Key? key) {
    final RenderBox? renderBox = _contextOffsetMap[key]?.context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      return renderBox.size;
    }
    return null;
  }

  Widget setFeedback(T data, Widget e, Key key) {
    return Builder(builder: (BuildContext context) {
      if (widget.maxSimultaneousDrags == 1 && data != dragData) {
        return const SizedBox.shrink();
      }

      final Size? size = getBoxSize(key);
      final Widget child = SizedBox(
        width: size?.width,
        height: size?.height,
        child: e,
      );
      return widget.buildFeedback?.call(data, e, size) ?? child;
    });
  }

  void _autoScrollIfNecessary(Offset details, Widget father) {
    // 1. 状态保护
    if (status != AnimationStatus.completed) {
      endAnimation();
      return;
    }

    // 2. 获取位置信息
    final ScrollPosition? position = _scrollable?.position ?? widget.scrollController?.position;
    if (position == null) {
      return;
    }

    final RenderBox scrollRenderBox =
        (_scrollable?.context.findRenderObject() ?? context.findRenderObject()) as RenderBox;
    final Offset scrollOrigin = scrollRenderBox.localToGlobal(Offset.zero);

    final double scrollStart = _offsetExtent(scrollOrigin, widget.scrollDirection);
    final double scrollEnd = scrollStart + _sizeExtent(scrollRenderBox.size, widget.scrollDirection);
    final double currentOffset = _offsetExtent(details, widget.scrollDirection);

    final double containerSize = _sizeExtent(scrollRenderBox.size, widget.scrollDirection);

    // 3. 计算动态阈值
    final double edgeThreshold = (containerSize * widget.edgeScroll).clamp(50.0, 120.0);

    // 计算最大速度 (pixels/second)
    // 容器尺寸 * 每秒滚动百分比 = 每秒最大滚动像素数
    final double maxVelocity = containerSize * widget.scrollSpeed;

    // 速度计算函数：线性插值 + 最小值保护
    double calculateVelocity(double intensity) {
      // 最小值设为最大速度的10%或者100逻辑像素，防止过慢
      final double minVelocity = (maxVelocity * 0.1).clamp(100.0, maxVelocity);
      return (maxVelocity * intensity).clamp(minVelocity, maxVelocity);
    }

    if (currentOffset < (scrollStart + edgeThreshold)) {
      // [上/左 边缘]
      double intensity = (scrollStart + edgeThreshold - currentOffset) / edgeThreshold;
      // 触发滚动：负速度
      _startTickerScroll(-calculateVelocity(intensity));
    } else if (currentOffset > (scrollEnd - edgeThreshold)) {
      // [下/右 边缘]
      double intensity = (currentOffset - (scrollEnd - edgeThreshold)) / edgeThreshold;
      // 触发滚动：正速度
      _startTickerScroll(calculateVelocity(intensity));
    } else {
      reSetWillAccept();
      endAnimation();
    }
  }

  // 优化4: 启动 Ticker 滚动逻辑
  void _startTickerScroll(double velocity) {
    _targetVelocity = velocity;
    if (_autoScrollTicker != null && _autoScrollTicker?.isTicking == false) {
      _lastTickTime = Duration.zero; // 重置 Tick 时间
      _autoScrollTicker?.start();
    }
  }

  // 优化5: 停止动画 (替代原 animateTo 的 Timer.cancel)
  void endAnimation() {
    _targetVelocity = 0.0;
    if (_autoScrollTicker != null && _autoScrollTicker?.isTicking == true) {
      _autoScrollTicker?.stop();
    }
  }

  double _offsetExtent(Offset offset, Axis scrollDirection) {
    switch (scrollDirection) {
      case Axis.horizontal:
        return offset.dx;
      case Axis.vertical:
        return offset.dy;
    }
  }

  double _sizeExtent(Size size, Axis scrollDirection) {
    switch (scrollDirection) {
      case Axis.horizontal:
        return size.width;
      case Axis.vertical:
        return size.height;
    }
  }

  @override
  void dispose() {
    endWillAccept();
    _autoScrollTicker?.dispose();
    scrollEndTimer?.cancel();
    super.dispose();
    _contextOffsetMap.clear();
  }
}
