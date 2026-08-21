import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/learning/data/models/material_item.dart';
import 'package:tutur_id_app/features/learning/logic/learning_provider.dart';

class SpellingQuestScreen extends ConsumerStatefulWidget {
  final String moduleId;
  const SpellingQuestScreen({super.key, required this.moduleId});

  @override
  ConsumerState<ConsumerStatefulWidget> createState() =>
      _SpellingQuestScreenState();
}

class _SpellingQuestScreenState extends ConsumerState<SpellingQuestScreen> {
  final _inputController = TextEditingController();
  String? _errorText;

  static const _options = ['ADA1', 'BACA02', 'MAMA4'];

  // Filter hanya A-M dan 0-4
  bool _isValidInput(String value) {
    return RegExp(r'^[A-Ma-m0-4]+$').hasMatch(value) && value.isNotEmpty;
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _startChallenge(String word) async {
    final lookup = await ref.read(materialsLookupProvider([1]).future);
    final materials = <MaterialItem>[];

    for (final char in word.toUpperCase().split('')) {
      final item = lookup[char];
      if (item != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Learning materials "$char" not implemented yet'),
            ),
          );
        }
        return;
      }
      materials.add(item!);
    }

    if (mounted) {
      context.push(
        '/ai-training/${widget.moduleId}',
        extra: {'materials': materials},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Spelling Quest I")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Choose ur word for spelling (A-M and 0-4)",
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: _options
                  .map(
                    (opt) => ActionChip(
                      label: Text(opt),
                      onPressed: () => _startChallenge(opt),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text("Or u can write down here..."),
            const SizedBox(height: 8),
            TextField(
              controller: _inputController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: "eg: BAJA123",
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final value = _inputController.text.trim();
                if (_isValidInput(value)) {
                  setState(() {
                    _errorText = "Only characters A-M and 0-4 allowed !";
                    return;
                  });
                }
                setState(() => _errorText = null);
                _startChallenge(value);
              },
              child: const Text('Start challange !'),
            ),
          ],
        ),
      ),
    );
  }
}
