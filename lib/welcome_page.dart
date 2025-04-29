
import 'package:flutter/material.dart';
class WelcomePage extends StatelessWidget {
  final String username;
  final int score;


  const WelcomePage({
    Key? key,
    required this.username,
    required this.score,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Bienvenue"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Welcome to the app",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text("Username: $username", style: TextStyle(fontSize: 18)),
            SizedBox(height: 10),
            Text(
              "Score: ${score.toStringAsFixed(2)}",
              style: TextStyle(fontSize: 18),
            ),
         
          
          ],
        ),
      ),
    );
  }
}