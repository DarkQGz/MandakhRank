import unittest
from datetime import datetime, timedelta, timezone
from .contest_rules import scoreboard


class ContestRulesTests(unittest.TestCase):
    def setUp(self):
        self.start = datetime(2026, 1, 1, tzinfo=timezone.utc)
        self.end = self.start + timedelta(minutes=60)
        self.points = {11: 100, 12: 50}

    def row(self, id, minute, status, user=1, task=11, passed=None, total=2):
        return (id, user, f'user{user}', task, status, (total if status == 'Accepted' else 0) if passed is None else passed, total, self.start+timedelta(minutes=minute))

    def calculate(self, rows):
        return scoreboard(rows, self.points, self.start, self.end)

    def test_out_of_order_worker_completion(self):
        rows, pending = self.calculate([self.row(3, 15, 'Accepted'), self.row(1, 3, 'Wrong Answer'), self.row(2, 10, 'Accepted')])
        self.assertEqual((rows[0]['score'], rows[0]['penalty'], rows[0]['solved'], pending), (100, 30, 1, 0))

    def test_deadline_and_invalid_accepted(self):
        rows, pending = self.calculate([self.row(1,-1,'Accepted'), self.row(2,60,'Accepted'), self.row(3,1,'Accepted',passed=0), self.row(4,3,'Accepted',total=0), self.row(5,5,'Accepted',task=99)])
        self.assertEqual(rows[0]['score'], 0)
        self.assertEqual(pending, 0)

    def test_compile_and_judge_errors_no_penalty(self):
        rows,_=self.calculate([self.row(1,1,'Compilation Error'), self.row(2,2,'Judge Error'), self.row(3,4,'Runtime Error'), self.row(4,8,'Accepted'),self.row(5,9,'Wrong Answer')])
        self.assertEqual((rows[0]['score'], rows[0]['penalty']), (100,28))

    def test_rank_ties_and_task_totals(self):
        rows,_=self.calculate([self.row(1,5,'Accepted',user=1),self.row(2,5,'Accepted',user=2),self.row(3,3,'Accepted',user=3,task=12),self.row(4,7,'Accepted',user=3)])
        self.assertEqual([(r['user_id'],r['rank'],r['score']) for r in rows],[(3,1,150),(1,2,100),(2,2,100)])

    def test_pending_and_unsolved(self):
        rows,pending=self.calculate([self.row(1,1,'Queued'),self.row(2,2,'Running'),self.row(3,3,'Wrong Answer',user=2)])
        self.assertEqual(pending,2)
        self.assertEqual(rows[0]['tasks']['11']['pending'],2)
        self.assertEqual([r['score'] for r in rows],[0,0])

    def test_earlier_pending_failure_recomputes(self):
        before,pending=self.calculate([self.row(1,2,'Running'),self.row(2,6,'Accepted')])
        after,done=self.calculate([self.row(1,2,'Wrong Answer'),self.row(2,6,'Accepted')])
        self.assertEqual((before[0]['penalty'],pending,after[0]['penalty'],done),(6,1,26,0))

    def test_at_start_and_same_minute(self):
        rows,_=self.calculate([self.row(2,0,'Accepted'),self.row(1,0,'Wrong Answer')])
        self.assertEqual(rows[0]['penalty'],20)
