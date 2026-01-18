import 'package:flutter/material.dart';

class RecipeListPage extends StatelessWidget {
  const RecipeListPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(title)));
  }
}
