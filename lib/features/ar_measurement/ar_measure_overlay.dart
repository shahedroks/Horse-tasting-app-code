import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ar_measure_provider.dart';

class ArMeasureOverlay extends StatelessWidget {
  const ArMeasureOverlay({super.key});

  String _instruction(ArMeasurePhase phase) {
    switch (phase) {
      case ArMeasurePhase.initializing:
      case ArMeasurePhase.scanning:
        return 'Move phone slowly to detect surfaces';
      case ArMeasurePhase.waitingFirstPoint:
        return 'Tap first point';
      case ArMeasurePhase.waitingSecondPoint:
        return 'Tap second point';
      case ArMeasurePhase.measured:
        return 'Measurement ready';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ArMeasureProvider>();
    final cm = provider.distanceCm;
    final inch = provider.distanceInches;

    return IgnorePointer(
      ignoring: false,
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            _instruction(provider.phase),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (cm != null && inch != null) ...[
                  Text(
                    'Distance: ${cm.toStringAsFixed(1)} cm',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  Text(
                    'Distance: ${inch.toStringAsFixed(2)} inches',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ] else
                  const Text(
                    'Distance: --',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => context.read<ArMeasureProvider>().reset(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white),
                      ),
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (cm != null && inch != null)
                            ? () => Navigator.of(context).pop()
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.tealAccent.shade400,
                          foregroundColor: Colors.black,
                        ),
                        child: const Text('Confirm'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

