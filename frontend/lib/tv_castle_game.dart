import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'theme_settings.dart';
import 'package:flutter/services.dart';

// This game is intentionally local-only. No practice/contest leaderboard points
// are granted and no student code is executed.
const Color _blue = Color(0xFF4C98FF);
const Color _orange = Color(0xFFFFA34B);

class _Topic {
  const _Topic(this.id, this.label, this.icon);
  final String id;
  final String label;
  final IconData icon;
}

const List<_Topic> _topics = [
  _Topic('all', 'Бүх төрөл', Icons.apps_rounded),
  _Topic('math', 'Математик', Icons.calculate_rounded),
  _Topic('easy', 'Хялбар алгоритм', Icons.route_rounded),
  _Topic('middle', 'Дунд шатны алгоритм', Icons.hub_rounded),
  _Topic('code', 'Програмчлал', Icons.code_rounded),
  _Topic('knowledge', 'Ерөнхий мэдлэг', Icons.public_rounded),
];

class _Question {
  const _Question(this.topic, this.prompt, this.code, this.options, this.answer);
  final String topic;
  final String prompt;
  final String code;
  final List<String> options;
  final int answer;
}

// Each topic contains at least twelve independently playable questions.
// Answer is a zero-based index into exactly four options.
const List<_Question> _questions = [
  // Математик
  _Question('math', '18 + 27 хэд вэ?', '', ['43', '45', '46', '47'], 1),
  _Question('math', '9 × 8 хэд вэ?', '', ['64', '72', '81', '78'], 1),
  _Question('math', '144 ÷ 12 хэд вэ?', '', ['10', '11', '12', '14'], 2),
  _Question('math', '200-ийн 15 хувь хэд вэ?', '', ['15', '25', '30', '35'], 2),
  _Question('math', '3, 6, 12, 24, ... дараагийн тоо хэд вэ?', '', ['30', '36', '48', '60'], 2),
  _Question('math', 'Периметр нь 20 см квадратын нэг тал хэдэн см вэ?', '', ['4', '5', '6', '10'], 1),
  _Question('math', '−7 + 12 хэд вэ?', '', ['−5', '4', '5', '19'], 2),
  _Question('math', '2-ын 5 зэрэг хэд вэ?', '', ['10', '16', '25', '32'], 3),
  _Question('math', '4, 8, 12 тоонуудын арифметик дундаж хэд вэ?', '', ['6', '8', '10', '12'], 1),
  _Question('math', 'Тэгш өнцөгтийн урт 8 см, өргөн 3 см бол талбай хэд вэ?', '', ['11 см²', '22 см²', '24 см²', '30 см²'], 2),
  _Question('math', '5/8 + 1/8 хэд вэ?', '', ['1/2', '3/4', '7/8', '1'], 1),
  _Question('math', 'x + 17 = 42 бол x хэд вэ?', '', ['23', '24', '25', '26'], 2),

  // Хялбар алгоритм
  _Question('easy', 'Давталт хэдэн удаа ажиллах вэ?', 'for i in range(4):\n    print(i)', ['3', '4', '5', '0'], 1),
  _Question('easy', 'Энэ код юу хэвлэх вэ?', 'a = [2, 4, 6]\nprint(a[0])', ['2', '4', '6', '0'], 0),
  _Question('easy', 'Энэ нөхцөл үнэн үү?', 'x = 7\nprint(x > 5)', ['True', 'False', '7', '5'], 0),
  _Question('easy', 'Энэ кодын хариу хэд вэ?', 's = 0\nfor x in [1, 2, 3]:\n    s += x\nprint(s)', ['3', '5', '6', '7'], 2),
  _Question('easy', 'Хамгийн их тоог олох зөв үйлдэл аль вэ?', 'a = [3, 9, 2]', ['min(a)', 'max(a)', 'len(a)', 'sum(a)'], 1),
  _Question('easy', 'Энэ код юу хэвлэх вэ?', 'print(len([5, 6, 7, 8]))', ['3', '4', '5', '8'], 1),
  _Question('easy', 'Өсөхөөр эрэмбэлэгдсэн жагсаалт аль вэ?', '', ['[8, 4, 2]', '[1, 3, 2]', '[2, 4, 8]', '[5, 5, 1]'], 2),
  _Question('easy', 'Энэ код юу хэвлэх вэ?', 'n = 6\nif n % 2 == 0:\n    print("тэгш")\nelse:\n    print("сондгой")', ['сондгой', 'тэгш', '6', '0'], 1),
  _Question('easy', 'Дараах давталтын эцэст x хэд болох вэ?', 'x = 1\nfor _ in range(3):\n    x *= 2\nprint(x)', ['4', '6', '8', '16'], 2),
  _Question('easy', 'Энэ кодын үр дүн хэд вэ?', 'print(17 // 5)', ['2', '3', '3.4', '4'], 1),
  _Question('easy', 'Жагсаалтын сүүлийн элементийг авахад аль индекс зөв вэ?', 'a = [10, 20, 30]', ['a[0]', 'a[1]', 'a[-1]', 'a[3]'], 2),
  _Question('easy', 'Энэ код юу хэвлэх вэ?', 'total = 0\nfor i in range(1, 4):\n    total += i\nprint(total)', ['3', '4', '6', '10'], 2),

  // Дунд шатны алгоритм
  _Question('middle', 'Эрэмбэлэгдсэн массивт хоёртын хайлтын хугацааны төвөгшил хэд вэ?', '', ['O(1)', 'O(log n)', 'O(n)', 'O(n²)'], 1),
  _Question('middle', 'Өргөнөөр хайх алгоритм нь жингүй графт юуг олж чаддаг вэ?', '', ['Хамгийн богино замын урт', 'Хамгийн их жинтэй зам', 'Бүх мөчлөгийн тоо', 'Бүх замын тоо'], 0),
  _Question('middle', 'Стек бүтцээс ямар элемент эхэлж гардаг вэ?', '', ['Хамгийн эхэлж хийсэн', 'Хамгийн сүүлд хийсэн', 'Хамгийн бага утгатай', 'Санамсаргүй'], 1),
  _Question('middle', 'Нэгтгэн эрэмбэлэх алгоритмын ердийн хугацааны төвөгшил хэд вэ?', '', ['O(n²)', 'O(n log n)', 'O(log n)', 'O(1)'], 1),
  _Question('middle', 'Эрэмбэлэгдсэн хоёр массивыг нэгтгэхэд тохиромжтой арга аль вэ?', '', ['Хоёр заагч', 'Санамсаргүй сонголт', 'Зөвхөн гүнээр хайх', 'Бүх хосыг шалгах'], 0),
  _Question('middle', 'Угтвар нийлбэрийн массив ямар асуултад тохиромжтой вэ?', '', ['Хэсгийн нийлбэр', 'Графын өнгө', 'Мөрийн урт', 'Хамгийн бага мөчлөг'], 0),
  _Question('middle', 'Дейкстрагийн стандарт алгоритмд ирмэгийн жин ямар байх ёстой вэ?', '', ['Заавал сөрөг', 'Сөрөг бус', 'Зөвхөн 1', 'Заавал тэг'], 1),
  _Question('middle', 'Дараалал өгөгдлийн бүтэц ямар зарчмаар ажилладаг вэ?', '', ['LIFO', 'FIFO', 'Хамгийн их утга эхэлж', 'Санамсаргүй'], 1),
  _Question('middle', 'Оруулан эрэмбэлэх алгоритмын хамгийн муу тохиолдлын төвөгшил хэд вэ?', '', ['O(1)', 'O(log n)', 'O(n)', 'O(n²)'], 3),
  _Question('middle', 'Хэш хүснэгтээс түлхүүрээр хайх дундаж хугацаа хэд вэ?', '', ['O(1)', 'O(log n)', 'O(n)', 'O(n²)'], 0),
  _Question('middle', 'Рекурсив функцэд зогсох үндсэн нөхцөл яагаад хэрэгтэй вэ?', '', ['Дахин дуудах үйл явцыг зогсоох', 'Санах ойг үргэлж нэмэх', 'Кодыг автоматаар эрэмбэлэх', 'Хувьсагчийг нуух'], 0),
  _Question('middle', 'Хоёртын хайлтыг зөв хэрэглэхийн өмнөх үндсэн шаардлага аль вэ?', '', ['Өгөгдөл эрэмбэлэгдсэн байх', 'Утга бүр өөр байх', 'Бүх утга сондгой байх', 'Массивын урт тэгш байх'], 0),

  // Програмчлал
  _Question('code', 'Python-д функц зарлах хоосон хэсэгт юу бичих вэ?', '___ greet():\n    print("Сайн уу")', ['func', 'def', 'function', 'method'], 1),
  _Question('code', 'Python-д утга буцаах түлхүүр үг аль вэ?', 'def double(x):\n    ___ x * 2', ['print', 'break', 'return', 'yield from'], 2),
  _Question('code', 'Жагсаалтын төгсгөлд нэг элемент нэмэх арга аль вэ?', 'a = [1, 2]\na.___(3)', ['append', 'remove', 'sort', 'clear'], 0),
  _Question('code', 'Python-д тэнцүү эсэхийг шалгах оператор аль вэ?', 'if a ___ b:\n    print("Тэнцүү")', ['=', '==', '!=', '>='], 1),
  _Question('code', 'Python-д хоёр нөхцөл хоёулаа үнэн байх оператор аль вэ?', 'if x > 0 ___ x < 10:\n    print(x)', ['or', 'not', 'and', 'in'], 2),
  _Question('code', 'Энэ Python код юу хэвлэх вэ?', 'print("код".upper())', ['код', 'КОД', 'Код', 'upper'], 1),
  _Question('code', 'Python-д зөвхөн 0, 1, 2 давтах код аль вэ?', '', ['range(2)', 'range(0, 3)', 'range(1, 3)', 'range(3, 0)'], 1),
  _Question('code', 'C++-д стандарт гаралт руу хэвлэхэд аль нь зөв вэ?', '', ['std::cout << 5;', 'std::cout >> 5;', 'std::cin << 5;', 'print(5);'], 0),
  _Question('code', 'Python-д алдааг барьж авах блокийн түлхүүр үг аль вэ?', '', ['else', 'except', 'finally', 'assert'], 1),
  _Question('code', 'Энэ код юу хэвлэх вэ?', 'x = {"a": 4, "b": 9}\nprint(x["b"])', ['a', 'b', '4', '9'], 3),
  _Question('code', 'Python-д мөрийн уртыг олох зөв дуудлага аль вэ?', 's = "hello"', ['size(s)', 's.length', 'len(s)', 'count(s)'], 2),
  _Question('code', 'JavaScript-д тогтмол зарлах түлхүүр үг аль вэ?', '', ['const', 'define', 'fixed', 'static'], 0),

  // Ерөнхий мэдлэг
  _Question('knowledge', 'Монгол Улсын нийслэл аль хот вэ?', '', ['Дархан', 'Эрдэнэт', 'Улаанбаатар', 'Ховд'], 2),
  _Question('knowledge', 'Нарны аймагт хэдэн гараг байдаг вэ?', '', ['7', '8', '9', '10'], 1),
  _Question('knowledge', 'Дэлхийн цорын ганц байгалийн дагуул юу вэ?', '', ['Нар', 'Сар', 'Ангараг', 'Сугар'], 1),
  _Question('knowledge', 'Ус далайн түвшний хэвийн даралтанд хэдэн °C-д хөлддөг вэ?', '', ['−10 °C', '0 °C', '10 °C', '100 °C'], 1),
  _Question('knowledge', 'Дэлхийн хамгийн өндөр уул аль вэ?', '', ['Килиманжаро', 'Эльбрус', 'Эверест', 'Фүжи'], 2),
  _Question('knowledge', 'Хүн анх саран дээр хэдэн онд газардсан бэ?', '', ['1959', '1965', '1969', '1975'], 2),
  _Question('knowledge', 'Япон Улсын нийслэл аль хот вэ?', '', ['Киото', 'Осака', 'Токио', 'Нагоя'], 2),
  _Question('knowledge', 'Химийн Na тэмдэг ямар элементийг илэрхийлдэг вэ?', '', ['Азот', 'Натри', 'Неон', 'Никель'], 1),
  _Question('knowledge', 'Нэг хоногт хэдэн цаг байдаг вэ?', '', ['12', '20', '24', '30'], 2),
  _Question('knowledge', 'Дэлхийн хамгийн том далай аль вэ?', '', ['Атлантын далай', 'Энэтхэгийн далай', 'Номхон далай', 'Хойд мөсөн далай'], 2),
  _Question('knowledge', 'Гэрэл ойролцоогоор секундэд хэдэн км хурдтай тархдаг вэ?', '', ['30 000 км', '300 000 км', '3 000 км', '3 000 000 км'], 1),
  _Question('knowledge', 'Монголын үндэсний уламжлалт эрийн гурван наадамд аль спорт багтдаг вэ?', '', ['Усан сэлэлт', 'Бөх барилдах', 'Сагсан бөмбөг', 'Теннис'], 1),
];

/// Local, single-screen battle for a touch TV. Both teams see the same question,
/// but answer independently using only their own half of the screen.
class TvCastleBattleScreen extends StatefulWidget {
  const TvCastleBattleScreen({super.key});

  @override
  State<TvCastleBattleScreen> createState() => _TvCastleBattleScreenState();
}

enum _Stage { setup, playing, results }

class _TvCastleBattleScreenState extends State<TvCastleBattleScreen>
    with TickerProviderStateMixin {
  MandakhPalette get palette => MandakhPalette.of(context);
  final TextEditingController _blueName = TextEditingController(text: 'Цэнхэр баг');
  final TextEditingController _orangeName = TextEditingController(text: 'Улбар шар баг');
  final math.Random _random = math.Random();
  late final AnimationController _ambient;
  late final AnimationController _blast;
  Timer? _clock;
  Timer? _next;

  _Stage _stage = _Stage.setup;
  String _topic = 'all';
  int _rounds = 10;
  int _roundSeconds = 20;
  List<_Question> _match = [];
  int _index = 0;
  int _blueHp = 16;
  int _orangeHp = 16;
  int _bluePoints = 0;
  int _orangePoints = 0;
  int? _bluePick;
  int? _orangePick;
  DateTime? _blueTime;
  DateTime? _orangeTime;
  DateTime? _deadline;
  bool _reveal = false;
  bool _blueFire = false;
  bool _orangeFire = false;
  int _blueDamage = 0;
  int _orangeDamage = 0;
  int _winner = 0;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(vsync: this, duration: Duration(seconds: 4))..repeat();
    _blast = AnimationController(vsync: this, duration: Duration(milliseconds: 1050));
    _clock = Timer.periodic(Duration(milliseconds: 200), (_) {
      if (!mounted || _stage != _Stage.playing || _reveal || _deadline == null) return;
      if (!DateTime.now().isBefore(_deadline!)) {
        _finishQuestion();
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _next?.cancel();
    _ambient.dispose();
    _blast.dispose();
    _blueName.dispose();
    _orangeName.dispose();
    super.dispose();
  }

  String get _blueLabel => _blueName.text.trim().isEmpty ? 'Цэнхэр баг' : _blueName.text.trim();
  String get _orangeLabel => _orangeName.text.trim().isEmpty ? 'Улбар шар баг' : _orangeName.text.trim();

  void _start() {
    final eligible = _questions.where((q) => _topic == 'all' || q.topic == _topic).toList()
      ..shuffle(_random);
    if (eligible.length < _rounds) return;
    _next?.cancel();
    _blast.reset();
    setState(() {
      _match = eligible.take(_rounds).toList();
      _index = 0;
      _blueHp = 16;
      _orangeHp = 16;
      _bluePoints = 0;
      _orangePoints = 0;
      _winner = 0;
      _stage = _Stage.playing;
      _resetRound();
    });
  }

  void _resetRound() {
    _bluePick = null;
    _orangePick = null;
    _blueTime = null;
    _orangeTime = null;
    _blueFire = false;
    _orangeFire = false;
    _blueDamage = 0;
    _orangeDamage = 0;
    _reveal = false;
    _deadline = DateTime.now().add(Duration(seconds: _roundSeconds));
  }

  void _choose(int side, int option) {
    if (_stage != _Stage.playing || _reveal) return;
    if (_deadline != null && !DateTime.now().isBefore(_deadline!)) {
      _finishQuestion();
      return;
    }
    if ((side == 1 && _bluePick != null) || (side == 2 && _orangePick != null)) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (side == 1) {
        _bluePick = option;
        _blueTime = DateTime.now();
      } else {
        _orangePick = option;
        _orangeTime = DateTime.now();
      }
    });
    if (_bluePick != null && _orangePick != null) _finishQuestion();
  }

  void _finishQuestion() {
    if (_stage != _Stage.playing || _reveal) return;
    final correct = _match[_index].answer;
    final b = _bluePick == correct;
    final o = _orangePick == correct;
    var bDamage = 0;
    var oDamage = 0;
    if (b && o) {
      if (!_blueTime!.isAfter(_orangeTime!)) {
        bDamage = 2;
        oDamage = 1;
      } else {
        bDamage = 1;
        oDamage = 2;
      }
    } else if (b) {
      bDamage = 2;
    } else if (o) {
      oDamage = 2;
    }
    setState(() {
      _reveal = true;
      _blueDamage = bDamage;
      _orangeDamage = oDamage;
      _blueFire = bDamage > 0;
      _orangeFire = oDamage > 0;
      _bluePoints += bDamage;
      _orangePoints += oDamage;
      _orangeHp = math.max(0, _orangeHp - bDamage);
      _blueHp = math.max(0, _blueHp - oDamage);
    });
    _blast.forward(from: 0);
    final ended = _blueHp == 0 || _orangeHp == 0 || _index + 1 >= _match.length;
    _next?.cancel();
    _next = Timer(Duration(milliseconds: 2300), () {
      if (!mounted) return;
      setState(() {
        if (ended) {
          _stage = _Stage.results;
          _winner = _blueHp > _orangeHp ? 1 : (_orangeHp > _blueHp ? 2 : 0);
        } else {
          _index++;
          _resetRound();
        }
      });
    });
  }

  void _newMatch() {
    _next?.cancel();
    setState(() {
      _stage = _Stage.setup;
      _deadline = null;
      _reveal = false;
      _blueFire = false;
      _orangeFire = false;
    });
    _blast.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        title: Text('Цайзын тулаан', style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          if (_stage != _Stage.setup)
            TextButton.icon(
              onPressed: _newMatch,
              icon: Icon(Icons.restart_alt_rounded),
              label: Text('Шинэ тоглоом'),
            ),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _stage == _Stage.setup ? _setupPage() : _battlePage(),
      ),
    );
  }

  Widget _setupPage() {
    return LayoutBuilder(builder: (context, constraints) {
      final roomy = constraints.maxWidth >= 850;
      return ListView(
        padding: EdgeInsets.symmetric(horizontal: roomy ? 30 : 16, vertical: 12),
        children: [
          Center(child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 1080),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: _decoration(context, palette.tint, palette.surface),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('НЭГ ДЭЛГЭЦ • ХОЁР БАГ', style: TextStyle(color: palette.accentInk, letterSpacing: 1.4, fontWeight: FontWeight.w900)),
                  SizedBox(height: 8),
                  Text('Цайзаа хамгаал, нөгөө багийн цайзыг довтол!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  SizedBox(height: 9),
                  Text('Хоёр баг зурагтын хоёр талд зогсоод нэг асуултад зэрэг хариулна. Зөв хариулбал нөгөө багийн цайз руу гэрэлт сум харвана. Хурдан зөв хариулсан баг илүү хүчтэй довтолно!', style: TextStyle(color: MandakhPalette.of(context).muted, height: 1.5)),
                  SizedBox(height: 14),
                  Wrap(spacing: 16, runSpacing: 8, children: [
                    _Hint(Icons.touch_app_rounded, 'Том мэдрэгч товч'),
                    _Hint(Icons.groups_rounded, '2 баг • Нэг төхөөрөмж'),
                    _Hint(Icons.tv_rounded, 'Зурагт дээр F11'),
                  ]),
                ]),
              ),
              SizedBox(height: 24),
              Text('Багуудын нэр', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(
                  controller: _blueName,
                  maxLength: 20,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.shield_rounded, color: _blue),
                    labelText: 'Зүүн тал • Цэнхэр баг',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )),
                SizedBox(width: 12),
                Expanded(child: TextField(
                  controller: _orangeName,
                  maxLength: 20,
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.shield_rounded, color: _orange),
                    labelText: 'Баруун тал • Улбар шар баг',
                    counterText: '',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )),
              ]),
              SizedBox(height: 24),
              Text('Асуултын төрөл сонгох', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 12, children: _topics.map((topic) => ChoiceChip(
                avatar: Icon(topic.icon, size: 20, color: _topic == topic.id ? palette.onAccent : palette.accentInk),
                label: Text(topic.label),
                selected: _topic == topic.id,
                selectedColor: palette.accentInk,
                backgroundColor: palette.surface,
                labelStyle: TextStyle(color: _topic == topic.id ? palette.onAccent : palette.text, fontWeight: FontWeight.w800),
                onSelected: (_) => setState(() => _topic = topic.id),
              )).toList()),
              SizedBox(height: 24),
              Text('Тоглоомын тохиргоо', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              SizedBox(height: 10),
              _choiceRow('Нийт асуулт', [6, 10, 12], _rounds, (v) => setState(() => _rounds = v)),
              SizedBox(height: 10),
              _choiceRow('Асуулт бүрийн хугацаа', [15, 20, 30], _roundSeconds, (v) => setState(() => _roundSeconds = v), suffix: ' сек'),
              SizedBox(height: 20),
              SizedBox(height: 62, child: FilledButton.icon(
                onPressed: _start,
                icon: Icon(Icons.play_arrow_rounded, size: 28),
                label: Text('ТУЛААН ЭХЛҮҮЛЭХ', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                style: FilledButton.styleFrom(backgroundColor: palette.accentInk, foregroundColor: palette.onAccent),
              )),
              SizedBox(height: 12),
              Text('Энэ нь нэг дэлгэцийн найрсаг тоглоом. Интернет, тусдаа өрөө, нэвтрэх эрх шаардлагагүй. Албан ёсны бодлогын оноонд нөлөөлөхгүй.', style: TextStyle(color: MandakhPalette.of(context).muted, fontSize: 12, height: 1.5)),
              SizedBox(height: 26),
            ]),
          )),
        ],
      );
    });
  }

  Widget _choiceRow(String label, List<int> options, int current, ValueChanged<int> onChange, {String suffix = ''}) {
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 8, children: [
      SizedBox(width: 220, child: Text(label, style: TextStyle(color: MandakhPalette.of(context).muted, fontWeight: FontWeight.w700))),
      ...options.map((n) => ChoiceChip(
        label: Text('$n$suffix'),
        selected: current == n,
        selectedColor: palette.accentInk,
        backgroundColor: palette.surface,
        labelStyle: TextStyle(color: current == n ? palette.onAccent : palette.text, fontWeight: FontWeight.bold),
        onSelected: (_) => onChange(n),
      )),
    ]);
  }

  Widget _battlePage() {
    final secondsLeft = _stage == _Stage.playing && !_reveal && _deadline != null
      ? math.max(0, (_deadline!.difference(DateTime.now()).inMilliseconds / 1000).ceil())
      : 0;
    final q = _match[_index];
    final isOver = _stage == _Stage.results;
    final w = MediaQuery.sizeOf(context).width;
    final wide = w >= 940;
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: wide ? 26 : 10, vertical: 6),
      children: [
        Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 1700), child: Column(children: [
          Row(children: [
            Expanded(child: _scoreBadge(_blueLabel, _blueHp, _bluePoints, _blue, true)),
            SizedBox(width: 8),
            Container(
              padding: EdgeInsets.symmetric(horizontal: wide ? 18 : 8, vertical: 12),
              decoration: BoxDecoration(color: palette.tint, borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text(isOver ? 'ДУУСЛАА' : 'ҮЕ ${_index + 1}/${_match.length}', style: TextStyle(color: MandakhPalette.of(context).muted, fontWeight: FontWeight.w900, fontSize: wide ? 14 : 10)),
                Text(_reveal ? '✓' : '$secondsLeft', style: TextStyle(fontSize: wide ? 28 : 23, fontWeight: FontWeight.w900, color: secondsLeft <= 5 && !_reveal ? palette.negative : palette.text)),
              ]),
            ),
            SizedBox(width: 8),
            Expanded(child: _scoreBadge(_orangeLabel, _orangeHp, _orangePoints, _orange, false)),
          ]),
          SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: wide ? 250 : 180,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: Listenable.merge([_ambient, _blast]),
                builder: (context, child) => CustomPaint(
                  painter: _CastlePainter(
                    blueHealth: _blueHp / 16,
                    orangeHealth: _orangeHp / 16,
                    glow: _ambient.value,
                    shot: _blast.value,
                    blueFire: _blueFire,
                    orangeFire: _orangeFire,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 13),
          if (isOver) _resultsPanel() else ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(wide ? 19 : 13),
              decoration: BoxDecoration(color: palette.surface, border: Border.all(color: palette.outline), borderRadius: BorderRadius.circular(17)),
              child: Column(children: [
                Text(_topics.firstWhere((e) => e.id == q.topic).label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: palette.accentInk)),
                SizedBox(height: 6),
                Text(q.prompt, textAlign: TextAlign.center, style: TextStyle(fontSize: wide ? 25 : 19, height: 1.2, fontWeight: FontWeight.w900)),
                if (q.code.isNotEmpty) ...[
                  SizedBox(height: 10),
                  Container(
                    constraints: BoxConstraints(maxWidth: 720),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(color: palette.background, borderRadius: BorderRadius.circular(12)),
                    child: SelectableText(q.code, textAlign: TextAlign.center, style: TextStyle(color: palette.accentInk, fontFamily: 'monospace', fontSize: wide ? 18 : 14, height: 1.4)),
                  ),
                ],
                if (_reveal) ...[
                  SizedBox(height: 9),
                  Text('Зөв хариулт: ${q.options[q.answer]}', textAlign: TextAlign.center, style: TextStyle(color: palette.positive, fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ]),
            ),
            SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _answers(1, q, wide)),
              SizedBox(width: 10),
              Expanded(child: _answers(2, q, wide)),
            ]),
            SizedBox(height: 10),
            Text(_reveal ? 'Дараагийн асуулт эхлэх гэж байна…' : 'Баг бүр зөвхөн өөрийн талын хариултад хүрнэ. Хоёр баг сонгомогц асуулт дуусна.', textAlign: TextAlign.center, style: TextStyle(color: MandakhPalette.of(context).muted, fontSize: 12)),
          ],
          SizedBox(height: 30),
        ]))),
      ],
    );
  }

  Widget _scoreBadge(String name, int health, int points, Color color, bool left) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(color: palette.surface, border: Border.all(color: color.withOpacity(.6)), borderRadius: BorderRadius.circular(15)),
      child: Column(crossAxisAlignment: left ? CrossAxisAlignment.start : CrossAxisAlignment.end, children: [
        Row(children: [
          if (left) Icon(Icons.shield_rounded, color: color, size: 22),
          if (left) SizedBox(width: 6),
          Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: left ? TextAlign.left : TextAlign.right, style: TextStyle(color: palette.readable(color), fontSize: 15, fontWeight: FontWeight.w900))),
          if (!left) SizedBox(width: 6),
          if (!left) Icon(Icons.shield_rounded, color: color, size: 22),
        ]),
        SizedBox(height: 5),
        Text('$health/16 хамгаалалт • $points оноо', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: MandakhPalette.of(context).muted, fontWeight: FontWeight.w700, fontSize: 12)),
        SizedBox(height: 7),
        ClipRRect(borderRadius: BorderRadius.circular(7), child: LinearProgressIndicator(value: health / 16, minHeight: 9, backgroundColor: palette.tint, valueColor: AlwaysStoppedAnimation(color))),
      ]),
    );
  }

  Widget _answers(int side, _Question question, bool wide) {
    final color = side == 1 ? _blue : _orange;
    final pick = side == 1 ? _bluePick : _orangePick;
    final damage = side == 1 ? _blueDamage : _orangeDamage;
    final name = side == 1 ? _blueLabel : _orangeLabel;
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(color: color.withOpacity(.075), border: Border.all(color: color.withOpacity(.5)), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.readable(color), fontWeight: FontWeight.w900, fontSize: wide ? 20 : 13)),
        SizedBox(height: 3),
        AnimatedSwitcher(
          duration: Duration(milliseconds: 200),
          child: Text(
            _reveal ? damage > 0 ? '+$damage ДОВТОЛГОО!' : pick == null ? 'Хугацаа дууслаа' : 'Буруу хариулт' : pick == null ? 'Хариултаа сонгоно уу' : 'Хариултаа өгсөн ✓',
            key: ValueKey('$side:$_reveal:$damage:$pick'),
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(color: _reveal && damage > 0 ? palette.positive : MandakhPalette.of(context).muted, fontSize: wide ? 13 : 11, fontWeight: FontWeight.w800),
          ),
        ),
        SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final twoCols = constraints.maxWidth >= 430;
          final gap = 8.0;
          final itemWidth = twoCols ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
          return Wrap(spacing: gap, runSpacing: gap, children: List.generate(4, (i) {
            final chosen = pick == i;
            final isCorrect = question.answer == i;
            final background = _reveal && isCorrect ? Color.lerp(palette.surface, palette.positive, .13)!
              : _reveal && chosen ? Color.lerp(palette.surface, palette.negative, .13)!
              : chosen ? Color.lerp(palette.surface, color, .15)! : palette.surface;
            return SizedBox(
              width: itemWidth,
              height: wide ? 76 : 82,
              child: Material(
                color: background,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: pick != null || _reveal ? null : () => _choose(side, i),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(border: Border.all(color: _reveal && isCorrect ? palette.positive : chosen ? color : palette.outline, width: chosen ? 2 : 1), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('${i + 1}. ${question.options[i]}', textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w800, fontSize: wide ? 17 : 13, color: MandakhPalette.contrast(palette.text, background) >= 4.5 ? palette.text : (MandakhPalette.contrast(Colors.white, background) >= MandakhPalette.contrast(Colors.black, background) ? Colors.white : Colors.black)))),
                  ),
                ),
              ),
            );
          }));
        }),
      ]),
    );
  }

  Widget _resultsPanel() {
    final title = _winner == 0 ? 'ТЭНЦЛЭЭ!' : '${_winner == 1 ? _blueLabel : _orangeLabel} ЯЛЛАА!';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(28),
      decoration: _decoration(context, palette.tint, palette.surface),
      child: Column(children: [
        Icon(_winner == 0 ? Icons.handshake_rounded : Icons.emoji_events_rounded, size: 74, color: Color(0xFFFFCA56)),
        SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        SizedBox(height: 12),
        Text('Цэнхэр: $_bluePoints оноо  •  Улбар шар: $_orangePoints оноо', textAlign: TextAlign.center, style: TextStyle(color: MandakhPalette.of(context).muted, fontSize: 16)),
        SizedBox(height: 24),
        SizedBox(height: 60, child: FilledButton.icon(onPressed: _newMatch, icon: Icon(Icons.replay_rounded), label: Text('ДАХИН ТОГЛОХ', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)))),
        SizedBox(height: 10),
        Text('Оноо зөвхөн энэ дэлгэц дээр хадгалагдана.', style: TextStyle(color: MandakhPalette.of(context).muted, fontSize: 12)),
      ]),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 18, color: MandakhPalette.of(context).accentInk),
    SizedBox(width: 6),
    Text(text, style: TextStyle(color: MandakhPalette.of(context).muted, fontWeight: FontWeight.w700)),
  ]);
}

BoxDecoration _decoration(BuildContext context, Color a, Color b) => BoxDecoration(
  gradient: LinearGradient(colors: [a, b]),
  border: Border.all(color: MandakhPalette.of(context).outline),
  borderRadius: BorderRadius.circular(20),
);

class _CastlePainter extends CustomPainter {
  const _CastlePainter({
    required this.blueHealth,
    required this.orangeHealth,
    required this.glow,
    required this.shot,
    required this.blueFire,
    required this.orangeFire,
  });

  final double blueHealth;
  final double orangeHealth;
  final double glow;
  final double shot;
  final bool blueFire;
  final bool orangeFire;

  Paint _p(Color color) => Paint()..color = color;

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final h = s.height;
    final sky = Rect.fromLTWH(0, 0, w, h);
    canvas.drawRect(sky, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF0D2751), Color(0xFF182044), Color(0xFF4C243B)],
    ).createShader(sky));

    // Twinkling sky and drifting cloud shapes.
    for (var i = 0; i < 26; i++) {
      final x = ((i * 77 + 29) % 997) / 997 * w;
      final y = ((i * 53 + 19) % 211) / 290 * h;
      final alpha = (0.2 + 0.35 * (1 + math.sin(glow * math.pi * 2 + i)) / 2);
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 1.8 : 1.0, _p(Colors.white.withOpacity(alpha)));
    }
    final cloud = Paint()..color = const Color(0xFF30436D).withOpacity(.32);
    for (var i = 0; i < 4; i++) {
      final cx = (i + .3) * w / 3.6 + math.sin(glow * 2 * math.pi + i) * 9;
      final cy = h * (.36 + (i % 2) * .1);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, cy), width: w * .16, height: 17), cloud);
    }

    canvas.drawRect(Rect.fromLTWH(0, h * .83, w, h * .17), _p(const Color(0xFF172C32)));
    canvas.drawRect(Rect.fromLTWH(0, h * .89, w, h * .11), _p(const Color(0xFF173D3C)));
    final leftX = w * .19;
    final rightX = w * .81;
    _castle(canvas, Offset(leftX, h * .84), w * .15, h * .34, const Color(0xFF5AA4FF), blueHealth, false);
    _castle(canvas, Offset(rightX, h * .84), w * .15, h * .34, const Color(0xFFFFA14B), orangeHealth, true);

    // Center magic crystal pulses independently of the score.
    final pulse = 1 + .08 * math.sin(glow * math.pi * 2);
    final crystal = Path()
      ..moveTo(w * .5, h * .37 - 21 * pulse)
      ..lineTo(w * .5 + 15 * pulse, h * .37)
      ..lineTo(w * .5, h * .37 + 21 * pulse)
      ..lineTo(w * .5 - 15 * pulse, h * .37)
      ..close();
    canvas.drawCircle(Offset(w * .5, h * .37), 31 * pulse, _p(const Color(0xFF91EBFF).withOpacity(.08)));
    canvas.drawPath(crystal, _p(const Color(0xFF9DEBFF)));
    canvas.drawPath(crystal, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white.withOpacity(.85));

    if (shot > 0 && shot < 1) {
      if (blueFire) _projectile(canvas, Offset(leftX + w * .08, h * .48), Offset(rightX - w * .08, h * .48), const Color(0xFF7EC1FF));
      if (orangeFire) _projectile(canvas, Offset(rightX - w * .08, h * .52), Offset(leftX + w * .08, h * .52), const Color(0xFFFFBB76));
    }
  }

  void _castle(Canvas canvas, Offset bottom, double width, double height, Color color, double hp, bool flip) {
    final x = bottom.dx;
    final ground = bottom.dy;
    final wallW = math.max(38.0, width * .72);
    final tW = math.max(16.0, width * .22);
    final towerY = ground - height * (hp <= .25 ? .64 : 1);
    final wall = Rect.fromLTWH(x - wallW / 2, ground - height * .69, wallW, height * .69);
    canvas.drawRRect(RRect.fromRectAndRadius(wall, const Radius.circular(3)), _p(Color.lerp(color, const Color(0xFF20314D), .46)!));
    for (final side in [-1, 1]) {
      final left = x + side * width * .36 - tW / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, towerY, tW, ground - towerY), const Radius.circular(3)), _p(color.withOpacity(.86)));
      for (var k = 0; k < 3; k++) {
        canvas.drawRect(Rect.fromLTWH(left + k * tW / 3, towerY - height * .09, tW / 5, height * .1), _p(color));
      }
    }
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x - width * .10, ground - height * .27, width * .2, height * .27), const Radius.circular(11)), _p(const Color(0xFF142437)));
    canvas.drawRect(Rect.fromLTWH(x - width * .39, ground - height * .36, width * .78 * hp.clamp(0, 1), height * .055), _p(hp < .35 ? const Color(0xFFFF5B70) : const Color(0xFF76F6B4)));
    final mastX = x + (flip ? width * .3 : -width * .3);
    canvas.drawLine(Offset(mastX, towerY - height * .1), Offset(mastX, towerY - height * .44), Paint()..color = Colors.white70..strokeWidth = 2);
    final flag = Path()
      ..moveTo(mastX, towerY - height * .43)
      ..lineTo(mastX + (flip ? -1 : 1) * width * .21, towerY - height * .36)
      ..lineTo(mastX, towerY - height * .29)
      ..close();
    canvas.drawPath(flag, _p(color));
    if (hp <= .30) {
      for (var k = 0; k < 3; k++) {
        canvas.drawCircle(Offset(x + (k - 1) * width * .26, ground - height * (.75 + k * .15)), 4 + k.toDouble(), _p(const Color(0xFFFF6E79).withOpacity(.6)));
      }
    }
  }

  void _projectile(Canvas canvas, Offset from, Offset to, Color color) {
    final t = Curves.easeInOutCubic.transform(shot);
    final spot = Offset.lerp(from, to, t)!;
    final arc = Offset(spot.dx, spot.dy - math.sin(t * math.pi) * 60);
    final trail = Offset.lerp(from, arc, .87)!;
    canvas.drawLine(trail, arc, Paint()..color = color.withOpacity(.65)..strokeWidth = 6..strokeCap = StrokeCap.round);
    canvas.drawCircle(arc, 13, _p(color.withOpacity(.20)));
    canvas.drawCircle(arc, 7, _p(color));
    if (t > .8) {
      final blast = (t - .8) / .2;
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final dist = 9 + 19 * blast;
        canvas.drawCircle(Offset(to.dx + math.cos(a) * dist, to.dy + math.sin(a) * dist), 3 * (1 - blast) + 1, _p(color.withOpacity((1 - blast).clamp(0.0, 1.0).toDouble())));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CastlePainter old) =>
      old.blueHealth != blueHealth || old.orangeHealth != orangeHealth ||
      old.glow != glow || old.shot != shot ||
      old.blueFire != blueFire || old.orangeFire != orangeFire;
}
