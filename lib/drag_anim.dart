import 'dart:async';

import 'package:drag_anim/anim.dart';
import 'package:flutter/material.dart';

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
    this.edgeScroll = 0.1,
    this.edgeScrollSpeedMilliseconds = 100,
    this.isEdgeScroll = true,
    this.isDrag = true,
    this.isNotDragList,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.maxSimultaneousDrags = 1,
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
  Timer? scrollEndTimer;
  Timer? _scrollableTimer;
  ScrollableState? _scrollable;
  AnimationStatus status = AnimationStatus.completed;
  bool isDragStart = false;
  bool isOnWillAccept = false;
  T? dragData;
  final Map<Key, ContextOffset> _contextOffsetMap = {};

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

  @override
  Widget build(BuildContext context) {
    return DragAnimNotification(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollStartNotification) {
          scrollEndTimer?.cancel();
        } else if (notification is ScrollEndNotification) {
          scrollEndTimer?.cancel();
          scrollEndTimer = Timer(const Duration(milliseconds: 150), () {
            if (!mounted) {
              return;
            }
            updateOffset();
          });
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

  bool setWillAccept(DragTargetDetails<T> details, T data) {
    if (details.data == data || (widget.maxSimultaneousDrags == 1 && details.data != dragData)) {
      return false;
    }
    if (status == AnimationStatus.completed) {
      endWillAccept();
      _timer = Timer(const Duration(milliseconds: 200), () {
        if (!DragAnimNotification.isScroll) {
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
      scrollController: widget.scrollController,
      key: key,
      child: DragTarget<T>(
        onWillAcceptWithDetails: (DragTargetDetails<T> details) {
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
    if (status != AnimationStatus.completed) {
      return;
    }
    if (_scrollable == null && widget.scrollController == null) {
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
    endWillAccept();
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
    _contextOffsetMap.clear();
  }
}
