import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class RenderAnimManage {
  RenderAnimManage(this.contextOffset, {this.isExecuteAnimation});

  late AnimationController controller;
  final ContextOffset? Function()? contextOffset;
  final bool Function()? isExecuteAnimation;

  Tween<Offset>? get tweenOffset {
    return contextOffset?.call()?.tweenOffset;
  }

  set tweenOffset(Tween<Offset>? value) {
    contextOffset?.call()?.tweenOffset = value;
  }

  Offset? get currentOffset {
    final RenderBox? renderBox = contextOffset?.call()?.context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final Offset position = renderBox.localToGlobal(Offset.zero);
      return position;
    }
    return Offset.zero;
  }

  set lastOffset(Offset? value) {
    Offset? offset = value;
    if (offset != null) {
      contextOffset?.call()?.offset = offset;
    }
  }

  Offset? get lastOffset => contextOffset?.call()?.offset;
}

class ContextOffset {
  ContextOffset(this.context, this.offset);

  BuildContext context;
  Offset offset;
  Tween<Offset>? tweenOffset;

  void updateOffset() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.attached && renderBox.hasSize) {
      offset = renderBox.localToGlobal(Offset.zero);
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          updateOffset();
        }
      });
    }
  }

  void clearTweenOffset() {
    tweenOffset = null;
  }
}
