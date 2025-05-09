import 'dart:math';
import 'package:flutter/material.dart';
import 'result_screen.dart'; // Import ResultScreen
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'LoginAuth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'EditAccount.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Explorer',
      home: SlotMachineWidget(),
      debugShowCheckedModeBanner: false,
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
   List<String> cuisines = [
    'Burgers', 'BBQ', 'Chinese', 'Hawaiian', 'Soul Food',
    'Pizza', 'Mexican', 'Italian', 'Steak', 'Seafood',
    'Thai', 'Indian', 'Japanese', 'Mediterranean', 'Korean',
  ];
   bool _showBounce = false;


   AnimationController? _controller;
  Animation<double>? _animation;
  final Random _random = Random();
  int selectedIndex = 0; // Track selected cuisine index


   @override
   void initState() {
     super.initState();
     _controller = AnimationController(duration: Duration(seconds: 3), vsync: this);

     // Delay listener setup until the first frame is rendered
     WidgetsBinding.instance.addPostFrameCallback((_) {
       _setupPreferenceListenerWhenSignedIn();
     });
   }
   void _setupPreferenceListenerWhenSignedIn() async {
     User? user;

     // Wait until FirebaseAuth has a user (retry loop)
     while (user == null) {
       user = FirebaseAuth.instance.currentUser;
       if (user == null) await Future.delayed(Duration(milliseconds: 100));
     }

     FirebaseFirestore.instance
         .collection('users')
         .doc(user.uid)
         .snapshots()
         .listen((doc) {
       if (doc.exists) {
         final data = doc.data();
         final prefs = List<String>.from(data?['preferences'] ?? []);

         setState(() {
           cuisines = [
             'Burgers', 'BBQ', 'Chinese', 'Hawaiian', 'Soul Food',
             'Pizza', 'Mexican', 'Italian', 'Steak', 'Seafood',
             'Thai', 'Indian', 'Japanese', 'Mediterranean', 'Korean',
           ];
           cuisines.addAll(prefs.where((p) => !cuisines.contains(p)));
         });
       }
     });
   }



   void _listenToPreferences() {
     final user = FirebaseAuth.instance.currentUser;
     if (user != null) {
       FirebaseFirestore.instance
           .collection('users')
           .doc(user.uid)
           .snapshots()
           .listen((doc) {
         if (doc.exists) {
           final data = doc.data();
           final prefs = List<String>.from(data?['preferences'] ?? []);

           setState(() {
             cuisines = [
               'Burgers', 'BBQ', 'Chinese', 'Hawaiian', 'Soul Food',
               'Pizza', 'Mexican', 'Italian', 'Steak', 'Seafood',
               'Thai', 'Indian', 'Japanese', 'Mediterranean', 'Korean',
             ];
             cuisines.addAll(prefs.where((p) => !cuisines.contains(p)));
           });
         }
       });
     }
   }



   Future<void> _spin() async {
    int rotations = _random.nextInt(10) + 10; // 10 to 19 full cycles
    int extraIndex = _random.nextInt(cuisines.length);
    int endValue = rotations * cuisines.length + extraIndex;

    _animation = Tween<double>(begin: 0, end: endValue.toDouble()).animate(
      CurvedAnimation(parent: _controller!, curve: Curves.easeOutBack),
    )..addListener(() {
      setState(() {
        selectedIndex = _animation!.value.floor() % cuisines.length;
      });
    });

    _controller?.reset();
    _controller?.forward().then((_) {
      setState(() {
        _showBounce = true;
      });

      // Wait for a moment so user sees the bounce
      Future.delayed(Duration(milliseconds: 800), () {
        setState(() {
          _showBounce = false;
        });

        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                ResultScreen(cuisine: cuisines[selectedIndex]),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: Duration(milliseconds: 500),
          ),
        );
      });
    });



  }

  void _navigateToAccountPage() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null){
     Navigator.push(
       context,
       MaterialPageRoute(builder: (context) => LoginAuth()),
     );
    }else {
      Navigator.push(
          context, MaterialPageRoute(builder: (context) => AccountPage()),
      );
      }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.yellow.shade100,
        shadowColor: Colors.black,
        elevation: 0,
        title: Text(
          '🍽️ FOOD EXPLORER',
          style: TextStyle(
            color: Colors.deepPurple,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(Icons.account_circle, color: Colors.deepPurple),
            onPressed: _navigateToAccountPage,
            label: Text(
              'Account',
              style: TextStyle(
                color: Colors.deepPurple,
                fontWeight: FontWeight.bold,
              ),
            ),

          ),

        ],
      ),

      body: Container(
    decoration: BoxDecoration(
    gradient: LinearGradient(
    colors: [Colors.yellow.shade50, Colors.red.shade100],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    ),
    ),
    child: Center(
    child: Column(
          mainAxisSize: MainAxisSize.min, // Ensures column takes only necessary space
          children: [
            Container(
              height: 100,
              width: 300,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
                border: Border.all(color: Colors.deepPurple.shade100, width: 2),
              ),
              child: AnimatedScale(
                scale: _showBounce ? 1.2 : 1.0,
                duration: Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                child: Text(
                  cuisines[selectedIndex],
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87 ,
                    letterSpacing: 1.2,
                  ),
                ),
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
            ),
    );
  }
}
