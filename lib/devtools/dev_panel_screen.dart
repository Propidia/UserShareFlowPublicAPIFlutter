import 'package:flutter/material.dart';
import 'api_test_runner.dart';

class DevPanelScreen extends StatefulWidget {
  const DevPanelScreen({super.key});

  @override
  State<DevPanelScreen> createState() => _DevPanelScreenState();
}

class _DevPanelScreenState extends State<DevPanelScreen> {
  String log = '';
  bool busy = false;

  void _append(String m) {
    setState(() => log = '${DateTime.now().toIso8601String()}  $m\n$log');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('لوحة المطوّر')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            final r = await ApiTestRunner.testFormsList();
                            _append('Forms ok, count=${r['count']}');
                          } catch (e) {
                            _append('Forms error: $e');
                          } finally {
                            setState(() => busy = false);
                          }
                        },
                  child: const Text('Test Get_IDs_Names'),
                ),
                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          try {
                            final r = await ApiTestRunner.testFormStructure(
                              2566,
                            );
                            _append(
                              'Structure 2566 ok, controls=${r['controls']}',
                            );
                          } catch (e) {
                            _append('Structure error: $e');
                          } finally {
                            setState(() => busy = false);
                          }
                        },
                  child: const Text('Test Bring_Controls (2566)'),
                ),
                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() => busy = true);
                          // try {
                          //   final r = await ApiTestRunner.testConnectedOptions(
                          //     formId: 2566,
                          //     controlId: 2,
                          //   );
                          //   _append(
                          //     'ConnectedOptions 2566/2 ok, items=${r['items']}',
                          //   );
                          // } catch (e) {
                          //   _append('ConnectedOptions error: $e');
                          // } finally {
                          //   setState(() => busy = false);
                          // }
                        },
                  child: const Text('Test Connected (2566,c2)'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Logs:'),
            const SizedBox(height: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: Text(
                    log,
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
