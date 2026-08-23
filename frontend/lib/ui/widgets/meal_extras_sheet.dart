import 'package:flutter/material.dart';

class MealExtrasSheet extends StatefulWidget {
  const MealExtrasSheet({super.key, required this.initialExtras});

  final List<String> initialExtras;

  @override
  State<MealExtrasSheet> createState() => _MealExtrasSheetState();
}

class _MealExtrasSheetState extends State<MealExtrasSheet> {
  static const _quickExtras = [
    'Brot',
    'Salat',
    'Quark',
    'Butter',
    'Hummus',
    'Reis',
  ];

  late final TextEditingController _controller = TextEditingController(
    text: widget.initialExtras.join(', '),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> _extras() {
    return _controller.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(8)
        .toList();
  }

  void _toggleQuickExtra(String value) {
    final extras = _extras();
    setState(() {
      if (extras.contains(value)) {
        extras.remove(value);
      } else {
        extras.add(value);
      }
      _controller.text = extras.join(', ');
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _extras();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Extras', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Beilagen und Extras',
                  hintText: 'Brot, Hummus, Salat',
                ),
                autofocus: true,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => Navigator.of(context).pop(_extras()),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final extra in _quickExtras)
                    FilterChip(
                      label: Text(extra),
                      selected: selected.contains(extra),
                      onSelected: (_) => _toggleQuickExtra(extra),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const <String>[]),
                    child: const Text('Leeren'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_extras()),
                    child: const Text('Fertig'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
