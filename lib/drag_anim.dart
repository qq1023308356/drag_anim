import 'dart:async';
import 'dart:developer';

import 'package:drag_anim/anim.dart';
import 'package:flutter/cupertino.dart';
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
    Key? key,
  }) : super(key: key);
  final Widget Function(List<Widget> children) buildItems;
  final Widget Function(T data, DragItems dragItems) items;
  final List<T> dataList;
  final Widget Function(T data, Widget child)? buildFeedback;
  final bool isLongPressDraggable;
  final Axis? axis;
  final void Function(T? moveData, T data, bool isFront)? onAccept;
  final bool Function(T? moveData, T data, bool isFront)? onWillAccept;
  final void Function(T? moveData, T data, bool isFront)? onLeave;
  final void Function(T data, DragTargetDetails<T> details, bool isFront)? onMove;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollable = Scrollable.of(context);
  }

  void setWillAccept(T? moveData, T data, {bool isFront = true}) {
    if (moveData == data) {
      return;
    }
    endWillAccept();
    _timer = Timer(const Duration(milliseconds: 200), () {
      if (!DragAnimNotification.isScroll) {
        if (widget.onWillAccept != null) {
          widget.onWillAccept?.call(moveData, data, isFront);
        } else if (moveData != null) {
          setState(() {
            final int index = widget.dataList.indexOf(data);
            if (isFront) {
              widget.dataList.remove(moveData);
              widget.dataList.insert(index, moveData);
            } else {
              widget.dataList.remove(moveData);
              if (index + 1 < widget.dataList.length) {
                widget.dataList.insert(index + 1, moveData);
              } else {
                widget.dataList.insert(index, moveData);
              }
            }
          });
        }
      }
    });
  }

  Widget setDragScope(T data, Widget child) {
    return DragAnimWidget(
        child: Stack(
          children: <Widget>[
            if (isDragStart && dragData == data) Opacity(opacity: 0.5, child: child) else child,
            if (isDragStart)
              Row(
                children: <Widget>[
                  Expanded(
                    child: DragTarget<T>(
                        onWillAccept: (T? moveData) {
                          setWillAccept(moveData, data);
                          return moveData != null;
                        },
                        onAccept: widget.onAccept == null
                            ? null
                            : (T moveData) => widget.onAccept?.call(moveData, data, true),
                        onLeave:
                        widget.onLeave == null ? null : (T? moveData) => widget.onLeave?.call(moveData, data, true),
                        onMove: widget.onMove == null
                            ? null
                            : (DragTargetDetails<T> details) => widget.onMove?.call(data, details, true),
                        hitTestBehavior: widget.hitTestBehavior,
                        builder: (BuildContext context, List<T?> candidateData, List<dynamic> rejectedData) {
                          return Container(color: Colors.transparent);
                        }),
                  ),
                  Expanded(
                    child: DragTarget<T>(
                        onWillAccept: (T? moveData) {
                          setWillAccept(moveData, data, isFront: false);
                          return moveData != null;
                        },
                        onAccept: widget.onAccept == null
                            ? null
                            : (T moveData) => widget.onAccept?.call(moveData, data, false),
                        onLeave: widget.onLeave == null
                            ? null
                            : (T? moveData) => widget.onLeave?.call(moveData, data, false),
                        onMove: widget.onMove == null
                            ? null
                            : (DragTargetDetails<T> details) => widget.onMove?.call(data, details, false),
                        hitTestBehavior: widget.hitTestBehavior,
                        builder: (BuildContext context, List<T?> candidateData, List<dynamic> rejectedData) {
                          return Container(color: Colors.transparent);
                        }),
                  ),
                ],
              ),
          ],
        ),
        onAnimationStatus: (AnimationStatus status) {
          this.status = status;
        });
  }

  Widget setDraggable(T data) {
    final Widget draggable = widget.items(data, (Widget father) {
      Widget child = setDragScope(data, father);

      if (widget.isLongPressDraggable) {
        child = LongPressDraggable<T>(
          feedback: setFeedback(data, father),
          axis: widget.axis,
          data: data,
          onDragStarted: () {
            dragData = data;
            setDragStart();
            widget.onDragStarted?.call(data);
          },
          onDragUpdate: (DragUpdateDetails details) {
            _autoScrollIfNecessary(details.globalPosition, father);
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
          axis: widget.axis,
          data: data,
          onDragStarted: () {
            dragData = data;
            setDragStart();
            widget.onDragStarted?.call(data);
          },
          onDragUpdate: (DragUpdateDetails details) {
            _autoScrollIfNecessary(details.globalPosition, father);
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
      return child;
    });
    return draggable;
  }

  Widget setFeedback(T data, Widget e) {
    return widget.buildFeedback?.call(data, e) ?? e;
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
    final double mediaQuery = _sizeExtent(MediaQuery.of(context).size, widget.scrollDirection) * 0.1;
    //print('????????????  ${currentOffset}  ${scrollStart}  ${scrollEnd}  ${scrollOrigin}');
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
    _scrollableTimer = Timer.periodic(const Duration(milliseconds: 200), (Timer timer) {
      if (isNext && position.pixels >= position.maxScrollExtent) {
        endAnimation();
      } else if (!isNext && position.pixels <= position.minScrollExtent) {
        endAnimation();
      } else {
        endWillAccept();
        position.animateTo(
          position.pixels + (isNext ? mediaQuery : -mediaQuery),
          duration: const Duration(milliseconds: 200),
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
