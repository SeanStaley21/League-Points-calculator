import 'package:flutter/material.dart';

/// Placeholder for the future Clubspeed .xls auto-import feature.
class AutoImportScreen extends StatelessWidget {
  const AutoImportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.upload_file_outlined,
              size: 48, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'This feature will be added soon',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Importing lap-time exports to auto-fill a week\'s results\nisn\'t available yet.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
