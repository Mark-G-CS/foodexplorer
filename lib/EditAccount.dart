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
  Future<void> _clearPreferences() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear Preferences?'),
        content: Text('Are you sure you want to delete all preferences?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('users').doc(user!.uid).update({
        'preferences': [],
      });
      _loadUserData();
    }
  }

  Future<void> _clearHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Clear History?'),
        content: Text('Are you sure you want to delete your entire food history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, clear'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore.collection('users').doc(user!.uid).update({
        'history': [],
      });
      _loadUserData();
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
              SizedBox(height: 24),

              // --- History Section ---
              Text("History",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                padding: EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 200, // 👈 set your max height
                  ),
                  child: history.isEmpty
                      ? Text("No history yet.")
                      : Scrollbar(
                    thumbVisibility: true,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(history[index]),
                        );
                      },
                    ),
                  ),
                ),
              ),
              if (history.isNotEmpty) ...[
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _clearHistory,
                    icon: Icon(Icons.delete_outline),
                    label: Text("Clear History"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade800,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],

              // --- Preferences Section ---
              Text("Preferences",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                padding: EdgeInsets.all(12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 200, // 👈 set your max height
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: preferences
                            .map((pref) => Chip(
                          label: Text(pref),
                          onDeleted: () => _removePreference(pref),
                        ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              if (preferences.isNotEmpty) ...[
                SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _clearPreferences,
                    icon: Icon(Icons.delete_sweep_outlined),
                    label: Text("Clear Preferences"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.deepOrange.shade800,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
              SizedBox(height: 24),
              // --- Add Preference Input ---
              Row(

                children: [
                  Expanded(
                    child: TextField(
                      controller: _preferenceController,
                      decoration: InputDecoration(
                        labelText: 'Add preference',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.add),
                    onPressed: () {
                      _addPreference(_preferenceController.text);
                    },
                  ),
                ],
              ),
              SizedBox(height: 24),
            ],
          ),

        ),
      ),
    );
  }
}
