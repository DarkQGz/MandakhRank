import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'practice_bank.dart';
import 'theme_settings.dart';

class LessonPractice extends StatefulWidget {
  const LessonPractice({super.key, required this.lesson});
  final Map<String, dynamic> lesson;
  @override
  State<LessonPractice> createState() => _LessonPracticeState();
}

class _LessonPracticeState extends State<LessonPractice> {
  final answer = TextEditingController();
  bool? correct;
  bool showSolution = false;
  bool showHint = false;

  @override
  void dispose() { answer.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final p = MandakhPalette.of(context);
    final title = widget.lesson['title']?.toString() ?? '';
    final example = widget.lesson['example']?.toString() ?? '';
    final entry = practiceBank[title];
    final exercise = entry != null && entry.sourceExample.trim() == example.trim() ? entry : null;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.outline));
    if (exercise == null) {
      // An edited/custom lesson must not be marked against an unrelated answer.
      return Material(color: p.surface, shape: shape, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.edit_note_rounded, color: p.accentInk, size: 30), const SizedBox(height: 12),
        const Text('Өөрөө турших', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10), Text(widget.lesson['practice']?.toString() ?? ''), const SizedBox(height: 12),
        TextField(controller: answer, minLines: 3, maxLines: 6, maxLength: 1000, decoration: const InputDecoration(labelText: 'Өөрийн хариулт', alignLabelWithHint: true)),
        Text('Энэ хичээлийн автомат шалгах дадлага хараахан бэлэн биш байна. Энд бичсэн хариулт хадгалагдахгүй.', style: TextStyle(color: p.muted, height: 1.45)),
      ])));
    }
    void check() {
      if (answer.text.trim().isEmpty) return;
      setState(() { correct = exercise.accepts(answer.text); showSolution = false; });
    }
    return Material(color: p.surface, shape: shape, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(Icons.code_rounded, color: p.accentInk, size: 28), const SizedBox(width: 10), const Expanded(child: Text('Өөрөө турших', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))), Text('01 / 01', style: TextStyle(color: p.muted, fontSize: 12))]),
      const SizedBox(height: 12), Text(exercise.prompt, style: const TextStyle(fontSize: 16, height: 1.5)),
      const SizedBox(height: 14),
      Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(12)), child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: SelectableText.rich(TextSpan(style: TextStyle(fontFamily: 'monospace', color: p.text, fontSize: 14, height: 1.6), children: [
        TextSpan(text: exercise.before),
        TextSpan(text: correct == true || showSolution ? exercise.answer : '____', style: TextStyle(color: correct == true ? p.positive : p.accentInk, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
        TextSpan(text: exercise.after),
      ])))),
      const SizedBox(height: 14),
      TextField(key: const ValueKey('practice-answer'), controller: answer, maxLength: 500, autocorrect: false, enableSuggestions: false, textCapitalization: TextCapitalization.none, smartQuotesType: SmartQuotesType.disabled, smartDashesType: SmartDashesType.disabled,
        style: const TextStyle(fontFamily: 'monospace'), textInputAction: TextInputAction.done, inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))],
        decoration: const InputDecoration(labelText: 'Дутуу кодыг бичих', hintText: 'Зөвхөн хоосон хэсгийг нөхнө үү.', counterText: ''),
        onChanged: (_) => setState(() { correct = null; showSolution = false; }), onSubmitted: (_) => check()),
      const SizedBox(height: 12),
      if (correct != null) ...[
        Semantics(liveRegion: true, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(correct == true ? Icons.check_circle_outline : Icons.error_outline, color: correct == true ? p.positive : p.negative), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(correct == true ? 'Зөв хариулт!' : 'Дахин оролдоорой.', style: TextStyle(color: correct == true ? p.positive : p.negative, fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(correct == true ? (exercise.explanation.isEmpty ? 'Кодын дутуу хэсгийг зөв нөхлөө. Дээр бүтэн код харагдаж байна.' : exercise.explanation) : 'Хоосон хэсэгт тохирох кодыг дахин шалгаарай. Том, жижиг үсэг болон тэмдэглэгээг анхаарна уу.', style: TextStyle(color: p.muted, height: 1.4))]))])),
        const SizedBox(height: 12),
      ],
      if (showHint) ...[Text('Санамж: ${exercise.prompt} Жишээ алхам дахь кодтой харьцуулж үзээрэй.', style: TextStyle(color: p.accentInk, height: 1.45)), const SizedBox(height: 10)],
      if (showSolution) ...[Text('Зөв нөхөх хэсэг: ${exercise.answer}', style: TextStyle(color: p.accentInk, fontFamily: 'monospace')), const SizedBox(height: 8)],
      Wrap(spacing: 8, runSpacing: 8, children: [OutlinedButton.icon(onPressed: () => setState(() => showHint = !showHint), icon: const Icon(Icons.lightbulb_outline), label: const Text('Санамж')), if (correct == false) TextButton(onPressed: () => setState(() => showSolution = !showSolution), child: Text(showSolution ? 'Хариу нуух' : 'Зөв хариу харах'))]),
      const SizedBox(height: 8), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: answer.text.trim().isEmpty ? null : check, icon: const Icon(Icons.check), label: const Text('Хариулт шалгах'))),
      const SizedBox(height: 12), Text('Энэ бол мэдлэгээ бататгах дадлага. Хичээлийг дуусгахын тулд дараагийн шалгалтад тэнцэнэ үү.', style: TextStyle(fontSize: 12, height: 1.45, color: p.muted)),
    ])));
  }
}
