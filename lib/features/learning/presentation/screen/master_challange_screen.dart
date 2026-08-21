import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tutur_id_app/features/learning/data/models/material_item.dart';
import 'package:tutur_id_app/features/learning/logic/learning_provider.dart';

class MasterChallengeScreen extends ConsumerStatefulWidget {
  final String moduleId;
  const MasterChallengeScreen({super.key, required this.moduleId});

  @override
  ConsumerState<MasterChallengeScreen> createState() =>
      _MasterChallengeScreenState();
}

class _MasterChallengeScreenState extends ConsumerState<MasterChallengeScreen> {
  List<MaterialItem>? _generatedSentence;
  bool _loading = false;

  Future<void> _generateChallenge() async {
    setState(() => _loading = true);

    // Semua kosakata Level 3 (lexical)
    final lookup = await ref.read(materialsLookupProvider([3]).future);
    final allWords = lookup.values.toList();

    if (allWords.length < 3) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Level 3 vocabulary is not sufficient to create a challenge.',
            ),
          ),
        );
        setState(() => _loading = false);
      }
      return;
    }

    allWords.shuffle(Random());
    final sentence = allWords.take(3).toList();

    setState(() {
      _generatedSentence = sentence;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('The Master Challenge')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'You will provide three random vocabulary words for you to act out in sequence.',
            ),
            const SizedBox(height: 24),
            if (_generatedSentence != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 8,
                    children: _generatedSentence!
                        .map((item) => Chip(label: Text(item.label)))
                        .toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.push(
                    '/ai-training/${widget.moduleId}',
                    extra: {'materials': _generatedSentence},
                  );
                },
                child: const Text('Start !'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _generateChallenge,
                child: const Text('Shuffle'),
              ),
            ] else
              ElevatedButton(
                onPressed: _loading ? null : _generateChallenge,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Create Challange'),
              ),
          ],
        ),
      ),
    );
  }
}
