import 'dart:async';

import 'package:flutter/cupertino.dart';

class DragAnimNotification extends StatefulWidget {
  const DragAnimNotification({required this.child, Key? key}) : super(key: key);
  final Widget child;
  static bool isScroll = false;

  @override
  State<StatefulWidget> createState() => DragAnimNotificationState();
}

class DragAnimNotificationState extends State<DragAnimNotification> {
  Timer? _timer;

  void setScroll() {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 100), () {
      DragAnimNotification.isScroll = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollStartNotification) {
          _timer?.cancel();
          DragAnimNotification.isScroll = true;
        } else if (notification is ScrollUpdateNotification) {
          _timer?.cancel();
          DragAnimNotification.isScroll = true;
        } else if (notification is ScrollEndNotification) {
          setScroll();
        }
        return false;
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
