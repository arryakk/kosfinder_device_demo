import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Halaman demo membaca data sensor accelerometer (linear acceleration).
class SensorDemoPage extends StatefulWidget {
  const SensorDemoPage({super.key});

  @override
  State<SensorDemoPage> createState() => _SensorDemoPageState();
}

class _SensorDemoPageState extends State<SensorDemoPage> {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  UserAccelerometerEvent? _latestEvent;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startListening();
  }

  void _startListening() {
    try {
      _subscription = userAccelerometerEventStream().listen(
        (UserAccelerometerEvent event) {
          if (mounted) {
            setState(() {
              _latestEvent = event;
              _errorMessage = null;
            });
          }
        },
        onError: (dynamic error) {
          if (mounted) {
            setState(() {
              _errorMessage =
                  'Sensor accelerometer tidak tersedia atau tidak didukung pada perangkat/emulator ini ($error).';
            });
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Gagal mengakses stream sensor: $e';
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Accelerometer'),
        backgroundColor: theme.colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Sensor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Halaman ini membaca User Accelerometer (akselerasi linier perangkat tanpa pengaruh gravitasi bumi) menggunakan package sensors_plus.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null)
              Card(
                color: theme.colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: theme.colorScheme.error),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              _buildAxisCard(
                label: 'Sumbu X (Lateral / Horizontal)',
                value: _latestEvent?.x,
                color: Colors.red.shade700,
                description: 'Pergerakan miring ke kiri / kanan',
              ),
              const SizedBox(height: 12),
              _buildAxisCard(
                label: 'Sumbu Y (Longitudinal / Vertikal)',
                value: _latestEvent?.y,
                color: Colors.green.shade700,
                description: 'Pergerakan miring ke atas / bawah',
              ),
              const SizedBox(height: 12),
              _buildAxisCard(
                label: 'Sumbu Z (Tegak Lurus Layar)',
                value: _latestEvent?.z,
                color: Colors.blue.shade700,
                description: 'Pergerakan maju / mundur layar',
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAxisCard({
    required String label,
    required double? value,
    required Color color,
    required String description,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  value != null
                      ? '${value.toStringAsFixed(2)} m/s²'
                      : 'Menunggu...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
