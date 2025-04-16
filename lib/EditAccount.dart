import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:foodexplorer2/LoginAuth.dart';
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  _AccountPageState createState() => _AccountPageState();
}
//TODO MAKE HISTORY SCROLLABLE, MAKE PREFERENCE SCROLLABLE
class _AccountPageState extends State<AccountPage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<String> history = [];
  List<String> preferences = [];
  final TextEditingController _preferenceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (user != null) {
      DocumentSnapshot snapshot =
      await _firestore.collection('users').doc(user!.uid).get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        setState(() {
          history = List<String>.from(data['history'] ?? []);
          preferences = List<String>.from(data['preferences'] ?? []);
        });
      }
    }
  }

  Future<void> _addPreference(String newPref) async {
    if (newPref.trim().isEmpty || preferences.contains(newPref.trim())) return;

    await _firestore.collection('users').doc(user!.uid).update({
      'preferences': FieldValue.arrayUnion([newPref.trim()]),
    });

    _preferenceController.clear();
    _loadUserData();
  }

  Future<void> _removePreference(String pref) async {
    await _firestore.collection('users').doc(user!.uid).update({
      'preferences': FieldValue.arrayRemove([pref]),
    });

    _loadUserData();
  }
  void _signOut() async {
    await FirebaseAuth.instance.signOut();

    // After signing out, send them to the login screen
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginAuth()),
      );

    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Account'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Log out',

          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: user == null
            ? Center(child: Text("Not signed in."))
            : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome, ${user!.displayName ?? 'User'}",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 20),

              // --- History ---
              Text("History:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ...history.map((h) => ListTile(title: Text(h))).toList(),
              Divider(),

              // --- Preferences ---
              Text("Preferences:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Wrap(
                spacing: 8.0,
                children: preferences
                    .map((pref) => Chip(
                  label: Text(pref),
                  onDeleted: () => _removePreference(pref),
                ))
                    .toList(),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _preferenceController,
                      decoration: InputDecoration(labelText: 'Add preference'),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      _addPreference(_preferenceController.text);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
