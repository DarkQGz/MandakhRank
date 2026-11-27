import csv
import io
import unittest
from datetime import datetime, timedelta, timezone
from .classroom_rules import assignment_status, parse_deadline, make_csv


class ClassroomRuleTests(unittest.TestCase):
    def test_status_boundaries(self):
        created = datetime(2026, 1, 1, tzinfo=timezone.utc)
        due = created + timedelta(days=1)
        after = due + timedelta(seconds=1)
        self.assertEqual(assignment_status(created, due, created, True, after), 'done')
        self.assertEqual(assignment_status(due, due, created, True, after), 'done')
        self.assertEqual(assignment_status(after, due, created, True, after), 'late')
        self.assertEqual(assignment_status(created-timedelta(seconds=1), due, created, True, after), 'prior')
        self.assertEqual(assignment_status(None, due, created, True, due), 'pending')
        self.assertEqual(assignment_status(None, due, created, True, after), 'overdue')
        self.assertEqual(assignment_status(None, None, created, True, after), 'pending')
        self.assertEqual(assignment_status(created, due, created, False, after), 'unavailable')

    def test_deadline(self):
        self.assertIsNone(parse_deadline(None))
        self.assertEqual(parse_deadline('2026-01-01T12:00:00+08:00'), datetime(2026,1,1,4,tzinfo=timezone.utc))
        for v in ('2026-01-01','2026-01-01T12:00:00','not a date',True,123,[]):
            with self.assertRaises(ValueError): parse_deadline(v)

    def test_csv_unicode_and_formula_protection(self):
        rows = [['Монгол, текст', '=1+1', '  @SUM(1)', '\tformula', 'normal', None, 'newline\ntext']]
        data = make_csv(rows)
        self.assertTrue(data.startswith('\ufeff'))
        self.assertEqual(list(csv.reader(io.StringIO(data[1:]))), [['Монгол, текст', "'=1+1", "'  @SUM(1)", "'\tformula", 'normal', '', 'newline\ntext']])
