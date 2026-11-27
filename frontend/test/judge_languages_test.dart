import 'package:flutter_test/flutter_test.dart';
import 'package:mandakhrank/judge_languages.dart';

void main() {
  test('old API and unknown languages fall back safely', () {
    expect(judgeLanguages(null), ['python']);
    expect(judgeLanguages(['ruby', 'cpp', 'cpp']), ['python', 'cpp']);
    expect(judgeLabel(null), 'Python 3');
  });
  test('five language IDs, names, files and starter templates align', () {
    expect(judgeLanguages(judgeLabels.keys.toList()), judgeLabels.keys.toList());
    expect(judgeFiles.keys.toSet(), judgeLabels.keys.toSet());
    expect(judgeTemplates.keys.toSet(), judgeLabels.keys.toSet());
    expect(judgeFiles['java'], 'Main.java');
    expect(judgeTemplates['java'], contains('public class Main'));
  });
}
