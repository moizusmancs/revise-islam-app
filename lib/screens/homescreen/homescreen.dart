import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar: AppBar(
        
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
       
        title: Text("temp"),
      ),
      body: Center(
       
        child: Column(
        
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
           
          ],
        ),
      ),
      
    );
  }
}