import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class DockerDesktopApp extends StatelessWidget {
  const DockerDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Docker Desktop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromARGB(255, 70, 8, 163)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
