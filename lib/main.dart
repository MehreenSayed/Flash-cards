import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const FlashCardsApp());

class Word {
  final String german;
  final String english;
  const Word(this.german, this.english);

  Map<String, String> toJson() => {'de': german, 'en': english};
  factory Word.fromJson(Map<String, dynamic> j) =>
      Word(j['de'] as String, j['en'] as String);
}

class FlashCardsApp extends StatelessWidget {
  const FlashCardsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'German Flash Cards',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
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
  static const _storageKey = 'words';
  final List<Word> _words = [];
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => Word.fromJson(e as Map<String, dynamic>));
    setState(() => _words.addAll(list));
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _storageKey, jsonEncode(_words.map((w) => w.toJson()).toList()));
  }

  void _add(Word w) {
    setState(() => _words.add(w));
    _save();
  }

  void _remove(int i) {
    setState(() => _words.removeAt(i));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('German Flash Cards')),
      body: _tab == 0
          ? AddWordsPage(words: _words, onAdd: _add, onRemove: _remove)
          : PracticePage(words: List.of(_words)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.edit), label: 'Add words'),
          NavigationDestination(icon: Icon(Icons.style), label: 'Practice'),
        ],
      ),
    );
  }
}

class AddWordsPage extends StatefulWidget {
  final List<Word> words;
  final void Function(Word) onAdd;
  final void Function(int) onRemove;
  const AddWordsPage({
    super.key,
    required this.words,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<AddWordsPage> createState() => _AddWordsPageState();
}

class _AddWordsPageState extends State<AddWordsPage> {
  final _de = TextEditingController();
  final _en = TextEditingController();
  final _deFocus = FocusNode();

  @override
  void dispose() {
    _de.dispose();
    _en.dispose();
    _deFocus.dispose();
    super.dispose();
  }

  void _submit() {
    final de = _de.text.trim();
    final en = _en.text.trim();
    if (de.isEmpty || en.isEmpty) return;
    widget.onAdd(Word(de, en));
    _de.clear();
    _en.clear();
    _deFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _de,
                    focusNode: _deFocus,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'German word',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _en,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      labelText: 'English meaning',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.add),
                      label: const Text('Add card'),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: widget.words.isEmpty
                  ? const Center(child: Text('No words yet. Add your first one!'))
                  : ListView.builder(
                      itemCount: widget.words.length,
                      itemBuilder: (context, i) {
                        final w = widget.words[i];
                        return ListTile(
                          title: Text(w.german),
                          subtitle: Text(w.english),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => widget.onRemove(i),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PracticePage extends StatefulWidget {
  final List<Word> words;
  const PracticePage({super.key, required this.words});

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  // Random.secure() gives a cryptographically strong source; shuffle()
  // is an unbiased Fisher-Yates shuffle.
  final _rng = Random.secure();
  late List<Word> _deck;
  int _index = 0;
  bool _showBack = false;

  @override
  void initState() {
    super.initState();
    _reshuffle();
  }

  void _reshuffle() {
    _deck = List.of(widget.words)..shuffle(_rng);
    _index = 0;
    _showBack = false;
  }

  void _go(int delta) {
    setState(() {
      _index = (_index + delta) % _deck.length;
      if (_index < 0) _index += _deck.length;
      _showBack = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_deck.isEmpty) {
      return const Center(child: Text('Add some words first to practice.'));
    }
    final word = _deck[_index];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Card ${_index + 1} of ${_deck.length}'),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _showBack = !_showBack),
                child: FlipCard(
                  showBack: _showBack,
                  front: word.german,
                  back: word.english,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Tap the card to flip'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filledTonal(
                    onPressed: () => _go(-1),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(_reshuffle),
                    icon: const Icon(Icons.shuffle),
                    label: const Text('Reshuffle'),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _go(1),
                    icon: const Icon(Icons.arrow_forward),
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

class FlipCard extends StatelessWidget {
  final bool showBack;
  final String front;
  final String back;
  const FlipCard({
    super.key,
    required this.showBack,
    required this.front,
    required this.back,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: showBack ? pi : 0),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      builder: (context, angle, _) {
        final isBack = angle > pi / 2;
        final scheme = Theme.of(context).colorScheme;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(angle),
          child: Container(
            width: double.infinity,
            height: 260,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isBack
                  ? scheme.secondaryContainer
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    blurRadius: 10, color: Colors.black26, offset: Offset(0, 4)),
              ],
            ),
            // Counter-rotate the text so the back side isn't mirrored.
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()..rotateY(isBack ? pi : 0),
              child: Text(
                isBack ? back : front,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        );
      },
    );
  }
}
