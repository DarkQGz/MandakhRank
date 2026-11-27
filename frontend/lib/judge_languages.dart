/// Shared API identifiers; unknown/old API responses fall back to Python.
const judgeLabels = <String, String>{
  'python': 'Python 3', 'c': 'C (C17)', 'cpp': 'C++ (C++17)',
  'java': 'Java 21', 'javascript': 'JavaScript (Node.js 22)',
};
const judgeFiles = <String, String>{
  'python': 'solution.py', 'c': 'main.c', 'cpp': 'main.cpp',
  'java': 'Main.java', 'javascript': 'main.js',
};
const judgeTemplates = <String, String>{
  'python': '# Python 3\n# input() ашиглан оролтоо уншина уу.\n',
  'c': '#include <stdio.h>\n\nint main(void) {\n    // Кодоо бичнэ үү.\n    return 0;\n}\n',
  'cpp': '#include <iostream>\nusing namespace std;\n\nint main() {\n    // Кодоо бичнэ үү.\n    return 0;\n}\n',
  'java': 'import java.util.*;\n\npublic class Main {\n    public static void main(String[] args) {\n        Scanner sc = new Scanner(System.in);\n        // Кодоо бичнэ үү.\n    }\n}\n',
  'javascript': "const fs = require('fs');\nconst input = fs.readFileSync(0, 'utf8').trim();\n// Кодоо бичнэ үү.\n",
};
List<String> judgeLanguages(Object? raw) => [
  for (final id in judgeLabels.keys)
    if (id == 'python' || (raw is List && raw.contains(id))) id,
];
String judgeLabel(Object? value) => judgeLabels[value] ?? judgeLabels['python']!;
