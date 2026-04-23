import 'package:flutter/material.dart';
import 'package:docker_desktop/data/docker_service_client.dart';

import 'dashboard_screen.dart';
import 'resources_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _svc = ClientDockerService();
  int _selected = 0;

  @override
  void dispose() {
    _svc.killprocesses();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      ResourcesScreen(svc: _svc),
      DashboardScreen(svc: _svc),
    ];

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selected,
            onDestinationSelected: (i) => setState(() => _selected = i),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: Text('Resources'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.insert_chart_outlined),
                selectedIcon: Icon(Icons.insert_chart),
                label: Text('Dashboard'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: pages[_selected]),
        ],
      ),
    );
  }
}
