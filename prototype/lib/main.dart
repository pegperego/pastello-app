// Throwaway prototype: validates the drawing engine on the reference device
// and in the browser. Not part of the app; see analisi/01-analisi-architetturale.md §7.
import 'package:flutter/material.dart';

import 'src/prototype_page.dart';
import 'src/tokens.dart';

void main() => runApp(const PrototypeApp());

class PrototypeApp extends StatelessWidget {
  const PrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pastello · prototipo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Tokens.coral,
          surface: Tokens.paper,
        ),
        scaffoldBackgroundColor: Tokens.paper,
      ),
      home: const PrototypePage(),
    );
  }
}
