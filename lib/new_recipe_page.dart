import 'package:flutter/material.dart';

class NewRecipePage extends StatelessWidget {
  const NewRecipePage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(title)));
  }
}
