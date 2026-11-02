"""Tests that do not require Docker, network, Django or CMS."""
import unittest
from unittest.mock import patch
from mandakhrank_pc_worker import evaluate, normalized, run_python, MAX_SOURCE_BYTES


class PCJudgeTests(unittest.TestCase):
    def job(self):
        return {'id': 17, 'claim_key': 'test-claim',
                'code': 'print(input())', 'expected_tests': 2,
                'tests': [{'stdin': 'alpha\n', 'expected': 'alpha\n'},
                          {'stdin': 'beta\n', 'expected': 'beta\n'}]}

    def test_accepted(self):
        seen = []
        def fake_run(code, stdin):
            seen.append(stdin)
            return 'OK', stdin
        self.assertEqual(evaluate(self.job(), run=fake_run,
                                  heartbeat=lambda path, key: None),
                         {'status': 'Accepted', 'passed': 2, 'total': 2})
        self.assertEqual(seen, ['alpha\n', 'beta\n'])

    def test_wrong_answer_stops(self):
        self.assertEqual(evaluate(self.job(), run=lambda *_: ('OK', 'other'),
                                  heartbeat=lambda *a: None),
                         {'status': 'Wrong Answer', 'passed': 0, 'total': 2})

    def test_second_test_timeout(self):
        calls = iter([('OK', 'alpha'), ('Time Limit Exceeded', '')])
        self.assertEqual(evaluate(self.job(), run=lambda *_: next(calls),
                                  heartbeat=lambda *a: None),
                         {'status': 'Time Limit Exceeded', 'passed': 1, 'total': 2})

    def test_private_test_snapshot_mismatch_rejected(self):
        job = self.job()
        job['expected_tests'] = 3
        with self.assertRaises(ValueError):
            evaluate(job, run=lambda *_: ('OK', ''), heartbeat=lambda *a: None)

    def test_whitespace_policy(self):
        self.assertEqual(normalized(' 10 \r\n\n'), normalized('10\n'))

    def test_source_limit_rejected(self):
        with self.assertRaises(ValueError):
            run_python('a' * (MAX_SOURCE_BYTES + 1), '')

    def test_heartbeat_each_test(self):
        events = []
        evaluate(self.job(), run=lambda _, data: ('OK', data),
                 heartbeat=lambda path, data: events.append((path, data)))
        self.assertEqual(len(events), 2)
        self.assertTrue(all(x[0] == '/api/judge/heartbeat/' for x in events))


if __name__ == '__main__':
    unittest.main()
