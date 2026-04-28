import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

class DockerDesktopApp extends StatelessWidget {
  const DockerDesktopApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color.fromARGB(255, 70, 8, 163);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Docker Desktop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: seed),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
