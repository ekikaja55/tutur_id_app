import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String? subTitle;
  final IconData icon;

  const PlaceholderScreen({
    super.key,
    required this.title,
    this.subTitle,
    this.icon = Icons.construction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subTitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subTitle!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              "Under construction",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
