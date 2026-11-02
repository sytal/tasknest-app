import 'package:flutter/material.dart';
import 'services/api_client.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskNest',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _status = 'Checking backend connection...';

  @override
  void initState() {
    super.initState();
    _checkBackend();
  }

  Future<void> _checkBackend() async {
    try {
      final response = await ApiClient.get('/health');
      setState(() {
        _status = response.statusCode == 200
            ? 'Backend connected: ${response.body}'
            : 'Backend responded with status ${response.statusCode}';
      });
    } catch (e) {
      setState(() {
        _status = 'Could not reach backend at ${ApiClient.baseUrl}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TaskNest')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_status, textAlign: TextAlign.center),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _checkBackend,
        tooltip: 'Retry',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
