import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DragLongPressDraggable<T extends Object> extends LongPressDraggable<T> {
  DragLongPressDraggable({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
    super.axis,
    super.childWhenDragging,
    super.feedbackOffset,
    super.dragAnchorStrategy,
    super.maxSimultaneousDrags,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDraggableCanceled,
    super.onDragEnd,
    super.onDragCompleted,
    super.hapticFeedbackOnStart = true,
    super.ignoringFeedbackSemantics,
    super.ignoringFeedbackPointer,
    super.delay = kLongPressTimeout,
    super.allowedButtonsFilter,
    super.hitTestBehavior,
    super.rootOverlay,
  });

  @override
  DelayedMultiDragGestureRecognizer createRecognizer(GestureMultiDragStartCallback onStart) {
    return DelayedMultiDragGestureRecognizer(
      delay: delay,
      allowedButtonsFilter: allowedButtonsFilter,
    )..onStart = (Offset position) {
        final Drag? result = onStart(position);
        if (result != null && hapticFeedbackOnStart) {
          HapticFeedback.selectionClick();
        }
        return _ProxyDrag(
          result,
          onUpdateCallback: (DragUpdateDetails details) {
            onDragUpdate?.call(details);
          },
        );
      };
  }
}

class DragDraggable<T extends Object> extends Draggable<T> {
  DragDraggable({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
    super.axis,
    super.childWhenDragging,
    super.feedbackOffset,
    super.dragAnchorStrategy,
    super.maxSimultaneousDrags,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDraggableCanceled,
    super.onDragEnd,
    super.onDragCompleted,
    super.ignoringFeedbackSemantics,
    super.ignoringFeedbackPointer,
    super.allowedButtonsFilter,
    super.hitTestBehavior,
    super.rootOverlay,
  });

  @override
  MultiDragGestureRecognizer createRecognizer(GestureMultiDragStartCallback onStart) {
    return switch (affinity) {
      Axis.horizontal => HorizontalMultiDragGestureRecognizer(
          allowedButtonsFilter: allowedButtonsFilter,
        ),
      Axis.vertical => VerticalMultiDragGestureRecognizer(
          allowedButtonsFilter: allowedButtonsFilter,
        ),
      null => ImmediateMultiDragGestureRecognizer(allowedButtonsFilter: allowedButtonsFilter),
    }
      ..onStart = (Offset position) {
        return _ProxyDrag(
          onStart(position),
          onUpdateCallback: (DragUpdateDetails details) {
            onDragUpdate?.call(details);
          },
        );
      };
  }
}

class _ProxyDrag extends Drag {
  final Drag? _realDrag;
  final void Function(DragUpdateDetails details) onUpdateCallback;

  _ProxyDrag(this._realDrag, {required this.onUpdateCallback});

  @override
  void update(DragUpdateDetails details) {
    onUpdateCallback(details);
    _realDrag?.update(details);
  }

  @override
  void end(DragEndDetails details) {
    _realDrag?.end(details);
  }

  @override
  void cancel() {
    _realDrag?.cancel();
  }
}
