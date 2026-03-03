import 'package:flutter/material.dart';

class GameBoardScreen extends StatelessWidget {
  const GameBoardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.green,
      body: Center(
        child: Text("מסך המשחק (בקרוב)", style: TextStyle(fontSize: 40, color: Colors.white)),
      ),
    );
  }
}