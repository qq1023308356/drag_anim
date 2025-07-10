import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class RenderAnimManage {
  RenderAnimManage(this.contextOffset, {this.isExecuteAnimation});

  Tween<Offset>? tweenOffset;
  late AnimationController controller;
  late Animation<double> animation;
  final ContextOffset? Function()? contextOffset;
  final bool Function()? isExecuteAnimation;

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

  final BuildContext context;
  Offset offset;

  void updateOffset() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      offset = renderBox.localToGlobal(Offset.zero);
    }
  }
}
