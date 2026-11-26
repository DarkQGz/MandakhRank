/// One short, local formative exercise. This never grants course completion.
class PracticeExercise {
  const PracticeExercise(this.sourceExample, this.prompt, this.before, this.after,
      this.answer, {this.explanation = '', this.alternatives = const [],
      this.ignoreCase = false, this.tokenized = true});

  final String sourceExample, prompt, before, after, answer, explanation;
  final List<String> alternatives;
  final bool ignoreCase, tokenized;

  // Keep whitespace inside strings and keep compound operators intact.
  static final _tokens = RegExp(r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|[A-Za-z_][A-Za-z_0-9]*|[0-9]+(?:\.[0-9]+)?|\*\*=|//=|<<=|>>=|==|!=|<=|>=|\+=|-=|\*=|/=|%=|&=|\|=|\^=|\*\*|//|<<|>>|=>|&&|\|\||\S''');

  String _normalize(String value) {
    final s = ignoreCase ? value.trim().toLowerCase() : value.trim();
    if (!tokenized) return s.replaceAll(RegExp(r'\s+'), ' ');
    return _tokens.allMatches(s).map((m) => m.group(0)!).join('\u001f');
  }

  bool accepts(String value) {
    if (value.trim().isEmpty || value.length > 500 ||
        value.contains('\n') || value.contains('\r')) return false;
    final candidate = _normalize(value);
    return [answer, ...alternatives].any((a) => _normalize(a) == candidate);
  }
}
