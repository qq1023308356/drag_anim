import 'dart:async';
import 'dart:developer';

import 'package:drag_anim/anim.dart';
import 'package:drag_anim/render_box_size.dart';
import 'package:flutter/material.dart';

import 'drag_anim_notification.dart';

typedef DragItems = Widget Function(Widget child);
typedef DragTargetOn<T> = Widget Function(T? moveData, T data);

class DragAnim<T extends Object> extends StatefulWidget {
  const DragAnim({
    required this.buildItems,
    required this.dataList,
    required this.items,
    this.isLongPressDraggable = true,
    this.buildFeedback,
    this.axis,
    this.onAccept,
    this.onWillAccept,
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
    this.isDragAnimNotification = false,
    this.draggingWidgetOpacity = 0.5,
    this.edgeScroll = 0.1,
    this.edgeScrollSpeedMilliseconds = 100,
    this.isEdgeScroll = true,
    this.isDrag = true,
    this.isNotDragList,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.maxSimultaneousDrags = 1,
    Key? key,
  }) : super(key: key);
  final Widget Function(List<Widget> children) buildItems;
  final Widget Function(T data, DragItems dragItems) items;
  final List<T> dataList;
  final Widget Function(T data, Widget child, Size? size)? buildFeedback;
  final bool isLongPressDraggable;
  final Axis? axis;
  final void Function(T? moveData, T data)? onAccept;
  final bool Function(T? moveData, T data, bool isTimer)? onWillAccept;
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
  final bool isDragAnimNotification;
  final double draggingWidgetOpacity;
  final double edgeScroll;
  final int edgeScrollSpeedMilliseconds;
  final bool isDrag;
  final List<T>? isNotDragList;
  final bool isEdgeScroll;
  final DragAnchorStrategy dragAnchorStrategy;
  final int maxSimultaneousDrags;

  @override
  State<StatefulWidget> createState() => DragAnimState<T>();
}

class DragAnimState<T extends Object> extends State<DragAnim<T>> {
  Timer? _timer;
  Timer? _scrollableTimer;
  ScrollableState? _scrollable;
  AnimationStatus status = AnimationStatus.completed;
  bool isDragStart = false;
  T? dragData;
  Map<T, Size> mapSize = <T, Size>{};

  void endWillAccept() {
    _timer?.cancel();
  }

  void setDragStart({bool isDragStart = true}) {
    if (this.isDragStart != isDragStart) {
      setState(() {
        this.isDragStart = isDragStart;
        if (!this.isDragStart) {
          dragData = null;
        } else {
          endWillAccept();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDragAnimNotification) {
      return DragAnimNotification(
        child: widget.buildItems(widget.dataList.map(setDraggable).toList()),
      );
    } else {
      return widget.buildItems(widget.dataList.map(setDraggable).toList());
    }
  }

  @override
  void didUpdateWidget(covariant DragAnim<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final List<T> delete = <T>[];
    mapSize.forEach((T key, Size value) {
      if (!widget.dataList.contains(key)) {
        delete.add(key);
      }
    });
    mapSize.removeWhere((T key, Size value) => delete.contains(key));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.scrollController == null) {
      try {
        _scrollable = Scrollable.of(context);
      } catch (e, s) {
        log('找不到控制器，需要添加 scrollController，$e \n $s');
      }
    }
  }

  void setWillAccept(T? moveData, T data) {
    if (moveData == data || (widget.maxSimultaneousDrags == 1 && moveData != dragData)) {
      return;
    }
    if (status == AnimationStatus.completed) {
      endWillAccept();
      _timer = Timer(const Duration(milliseconds: 200), () {
        if (!DragAnimNotification.isScroll) {
          if (widget.onWillAccept != null) {
            widget.onWillAccept?.call(moveData, data, true);
          } else if (moveData != null) {
            setState(() {
              final int index = widget.dataList.indexOf(data);
              widget.dataList.remove(moveData);
              widget.dataList.insert(index, moveData);
            });
          }
        }
      });
    }
  }

  bool isContains(T data) {
    final List<T>? isNotDragList = widget.isNotDragList;
    if (isNotDragList != null) {
      return isNotDragList.contains(data);
    }
    return false;
  }

  Size? getRenderBoxSize(T? date) {
    return mapSize[date];
  }

  Widget setDragScope(T data, Widget child) {
    final Widget keyWidget = child;
    return DragAnimWidget(
        child: DragTarget<T>(
          onWillAccept: (T? moveData) {
            widget.onWillAccept?.call(moveData, data, false);
            if (isDragStart) {
              setWillAccept(moveData, data);
              return moveData != null;
            }
            return false;
          },
          onAccept: widget.onAccept == null ? null : (T moveData) => widget.onAccept?.call(moveData, data),
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
          this.status = status;
        });
  }

  Widget setDraggable(T data) {
    final Widget draggable = widget.items(data, (Widget father) {
      Widget child = setDragScope(data, father);
      int maxSimultaneousDrags = widget.maxSimultaneousDrags;
      if (maxSimultaneousDrags == 1 && dragData != null && dragData != data) {
        maxSimultaneousDrags = 0;
      }
      if (widget.isDrag && !isContains(data)) {
        if (widget.isLongPressDraggable) {
          child = LongPressDraggable<T>(
            feedback: setFeedback(data, father),
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
        } else {
          child = Draggable<T>(
            feedback: setFeedback(data, father),
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
    });
    return RenderBoxSize(
      draggable,
      (Size size) {
        mapSize[data] = size;
      },
      key: ValueKey<T>(data),
    );
  }

  Widget setFeedback(T data, Widget e) {
    return Builder(builder: (BuildContext context) {
      if (widget.maxSimultaneousDrags == 1 && data != dragData) {
        return const SizedBox.shrink();
      }
      final Size? size = getRenderBoxSize(data);
      final Widget child = SizedBox(
        width: size?.width,
        height: size?.height,
        child: e,
      );
      return widget.buildFeedback?.call(data, e, size) ?? child;
    });
  }

  void _autoScrollIfNecessary(Offset details, Widget father) {
    if (status != AnimationStatus.completed) {
      return;
    }
    if (_scrollable == null && widget.scrollController == null) {
      log("_scrollable == null && widget.scrollController == null");
      return;
    }
    final RenderBox scrollRenderBox;
    if (_scrollable != null) {
      scrollRenderBox = _scrollable!.context.findRenderObject()! as RenderBox;
    } else {
      scrollRenderBox = context.findRenderObject()! as RenderBox;
    }
    final Offset scrollOrigin = scrollRenderBox.localToGlobal(Offset.zero);
    final double scrollStart = _offsetExtent(scrollOrigin, widget.scrollDirection);
    final double scrollEnd = scrollStart + _sizeExtent(scrollRenderBox.size, widget.scrollDirection);
    final double currentOffset = _offsetExtent(details, widget.scrollDirection);
    final double mediaQuery = _sizeExtent(MediaQuery.of(context).size, widget.scrollDirection) * widget.edgeScroll;
    //print('当前位置  ${currentOffset}  ${scrollStart}  ${scrollEnd}  ${scrollOrigin}');
    if (currentOffset < (scrollStart + mediaQuery)) {
      animateTo(mediaQuery, isNext: false);
    } else if (currentOffset > (scrollEnd - mediaQuery)) {
      animateTo(mediaQuery);
    } else {
      endAnimation();
    }
  }

  void animateTo(double mediaQuery, {bool isNext = true}) {
    final ScrollPosition position = _scrollable?.position ?? widget.scrollController!.position;
    endAnimation();
    if (isNext && position.pixels >= position.maxScrollExtent) {
      return;
    } else if (!isNext && position.pixels <= position.minScrollExtent) {
      return;
    }
    DragAnimNotification.isScroll = true;
    _scrollableTimer = Timer.periodic(Duration(milliseconds: widget.edgeScrollSpeedMilliseconds), (Timer timer) {
      if (isNext && position.pixels >= position.maxScrollExtent) {
        endAnimation();
      } else if (!isNext && position.pixels <= position.minScrollExtent) {
        endAnimation();
      } else {
        endWillAccept();
        position.animateTo(
          position.pixels + (isNext ? mediaQuery : -mediaQuery),
          duration: Duration(milliseconds: widget.edgeScrollSpeedMilliseconds),
          curve: Curves.linear,
        );
      }
    });
  }

  void endAnimation() {
    DragAnimNotification.isScroll = false;
    _scrollableTimer?.cancel();
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
    endAnimation();
    super.dispose();
  }
}
