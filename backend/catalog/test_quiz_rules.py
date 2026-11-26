import hashlib
import json
import unittest
from pathlib import Path
from .quiz_rules import valid_answer, is_correct, answer_text

HERE = Path(__file__).resolve().parent

class QuizRuleTests(unittest.TestCase):
    def test_curriculum_coverage(self):
        bank = json.loads((HERE/'learning_questions.json').read_text(encoding='utf-8'))
        courses = json.loads((HERE/'course_bank_160.json').read_text(encoding='utf-8'))
        prompts = set()
        self.assertEqual(len(courses), 16)
        self.assertEqual(set(bank), {c['title'] for c in courses})
        for c in courses:
            self.assertEqual(set(bank[c['title']]), {l['title'] for l in c['lessons']})
            for l in c['lessons']:
                r = bank[c['title']][l['title']]
                self.assertEqual(r['sha256'], hashlib.sha256(l['content'].encode()).hexdigest())
                self.assertEqual(len(r['questions']), 5)
                self.assertEqual(sum(q.get('kind') in ('fill','short') for q in r['questions']), 1)
                self.assertEqual(sum(q.get('kind') == 'true_false' for q in r['questions']), 1)
                for q in r['questions'] + [r['final']]:
                    self.assertNotIn(q['prompt'], prompts)
                    prompts.add(q['prompt'])
                    if q.get('kind') in ('fill','short'):
                        self.assertTrue(q['accepted'])
                        self.assertTrue(q['explanation'])
                        for a in q['accepted']:
                            self.assertTrue(is_correct(q, a))
                        self.assertFalse(is_correct(q, '__invalid_answer__'))
                    else:
                        self.assertEqual(len(set(q['choices'])), len(q['choices']))
                        self.assertIn(q['correct'], range(len(q['choices'])))
        self.assertEqual(len(prompts), 960)

    def test_typed_case_and_whitespace(self):
        q = {'kind':'fill','casefold':False,'accepted':['False']}
        self.assertTrue(is_correct(q, ' False '))
        self.assertFalse(is_correct(q, 'false'))
        self.assertFalse(is_correct(q, 'False; print(1)'))
        self.assertFalse(is_correct(q, 'False\n'))
        self.assertEqual(answer_text(q, ' False '), 'False')
        q = {'kind':'fill','casefold':True,'accepted':['SELECT']}
        self.assertTrue(is_correct(q, 'select'))

    def test_invalid_inputs(self):
        q = {'kind':'short','casefold':False,'accepted':['3']}
        for value in (None, 3, [], {}, '', '  ', 'a'*201, '\x00', '3\n'):
            self.assertFalse(valid_answer(q, value))
            self.assertFalse(is_correct(q, value))
        self.assertTrue(valid_answer(q, '2'))
        self.assertFalse(is_correct(q, '2'))

    def test_choice_ids_only(self):
        q = {'kind':'true_false','correct':'a','options':[{'id':'a','text':'Үнэн'},{'id':'b','text':'Худал'}]}
        self.assertTrue(is_correct(q, 'a'))
        self.assertTrue(valid_answer(q, 'b'))
        self.assertFalse(is_correct(q, 'b'))
        self.assertFalse(valid_answer(q, 'Үнэн'))
        self.assertEqual(answer_text(q, 'a'), 'Үнэн')
