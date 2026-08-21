import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/learning/data/models/material_item.dart';
import 'package:tutur_id_app/features/learning/logic/learning_provider.dart';

class IdentityChallengeScreen extends ConsumerStatefulWidget {
  final String moduleId;
  const IdentityChallengeScreen({super.key, required this.moduleId});

  @override
  ConsumerState<IdentityChallengeScreen> createState() =>
      _IdentityChallengeScreenState();
}

class _IdentityChallengeScreenState
    extends ConsumerState<IdentityChallengeScreen> {
  final _nameController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _startChallenge() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Ur name cannot be empty !');
      return;
    }

    // Level 2 sudah lengkap A-Z, jadi lookup dari level 1 + 2
    final lookup = await ref.read(materialsLookupProvider([1, 2]).future);

    final onlyLetters = name.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (onlyLetters.isEmpty) {
      setState(() => _errorText = 'Ur name must contain any character !');
      return;
    }

    final materials = <MaterialItem>[];
    for (final char in onlyLetters.split('')) {
      final item = lookup[char];
      if (item == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Learning materials "$char" not implemented yet'),
            ),
          );
        }
        return;
      }
      materials.add(item);
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
      appBar: AppBar(title: const Text('The Identity')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Type ur full name, than demonstrate them !',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: 'Full Name',
                errorText: _errorText,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _startChallenge,
              child: const Text('Start Challange !'),
            ),
          ],
        ),
      ),
    );
  }
}
