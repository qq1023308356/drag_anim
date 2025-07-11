import 'package:drag_anim/drag_anim.dart';
import 'package:flutter/material.dart';

class DoubleSliverPage extends StatefulWidget {
  const DoubleSliverPage({super.key, required this.title});

  final String title;

  @override
  State<DoubleSliverPage> createState() => _DoubleSliverPageState();
}

class _DoubleSliverPageState extends State<DoubleSliverPage> {
  List<A> itemsA = [A('1'), A('2'), A('3'), A('4'), A('5'), A('6')];

  List<B> itemsB = [B('1'), B('2'), B('3'), B('4'), B('5'), B('6')];
  ScrollController scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Theme.of(context).colorScheme.inversePrimary, title: Text(widget.title)),
      body: DragAnim<Object>(
        scrollController: scrollController,
        scrollDirection: Axis.vertical,
        onWillAcceptWithDetails: (DragTargetDetails<Object> details, Object data, bool isTimer) {
          var list = data is A && details.data is A ? itemsA : (data is B && details.data is B ? itemsB : null);
          if (list != null) {
            setState(() {
              final int index = list.indexOf(data);
              list.remove(details.data);
              list.insert(index, details.data);
            });
          }
          return list != null;
        },
        buildItems: (dragItems) {
          return CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverAppBar(
                expandedHeight: 190.0,
                title: const Text('Test'),
                elevation: 5,
                pinned: true,
                backgroundColor: Colors.orange,
              ),
              SliverGrid.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: itemsA.length,
                itemBuilder: (BuildContext context, int index) {
                  return dragItems(
                    data: itemsA[index],
                    child: Container(
                      color: Colors.red,
                      alignment: Alignment.center,
                      child: Text(
                        itemsA[index].value,
                        style: const TextStyle(fontSize: 30, color: Colors.white, decoration: TextDecoration.none),
                      ),
                    ),
                    key: ValueKey<A>(itemsA[index]),
                  );
                },
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, int index) => dragItems(
                    data: itemsB[index],
                    child: Container(
                      color: Colors.red,
                      alignment: Alignment.center,
                      child: Text(
                        itemsB[index].value,
                        style: const TextStyle(fontSize: 30, color: Colors.white, decoration: TextDecoration.none),
                      ),
                    ),
                    key: ValueKey<B>(itemsB[index]),
                  ),
                  childCount: itemsB.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class A {
  A(this.value);

  final String value;
}

class B {
  B(this.value);

  final String value;
}
