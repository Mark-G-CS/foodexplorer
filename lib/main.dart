import 'dart:math';
import 'package:flutter/material.dart';
import 'result_screen.dart'; // Import ResultScreen

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Slot Machine',
      home: SlotMachineWidget(),
    );
  }
}

class SlotMachineWidget extends StatefulWidget {
  const SlotMachineWidget({super.key});

  @override
  _SlotMachineWidgetState createState() => _SlotMachineWidgetState();
}

class _SlotMachineWidgetState extends State<SlotMachineWidget>
    with SingleTickerProviderStateMixin {
  final List<String> cuisines = [
    'Burgers', 'BBQ', 'Chinese', 'Hawaiian', 'Soul Food',
    'Pizza', 'Mexican', 'Italian', 'Steak', 'Seafood',
    'Thai', 'Indian', 'Japanese', 'Mediterranean', 'Korean',
  ];

  AnimationController? _controller;
  Animation<double>? _animation;
  final Random _random = Random();
  int selectedIndex = 0; // Track selected cuisine index

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: Duration(seconds: 3), vsync: this);
  }

  void _spin() {
    int rotations = _random.nextInt(10) + 10; // 10 to 19 full cycles
    int extraIndex = _random.nextInt(cuisines.length);
    int endValue = rotations * cuisines.length + extraIndex;

    _animation = Tween<double>(begin: 0, end: endValue.toDouble()).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.decelerate),
    )..addListener(() {
      setState(() {
        selectedIndex = _animation!.value.floor() % cuisines.length;
      });
    });

    _controller?.reset();
    _controller?.forward().then((_) {
      // Navigate to ResultScreen after animation ends
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ResultScreen(cuisine: cuisines[selectedIndex])),
      );
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Food Slot Machine')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min, // Ensures column takes only necessary space
          children: [
            Container(
              height: 100,
              width: 300,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                cuisines[selectedIndex],
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: _spin,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
              child: Text("Spin", style: TextStyle(fontSize: 24)),
            ),
          ],
        ),
      ),

    );
  }
}
