"""Pure rule tests, runnable even without Django installed."""
from collections import Counter
from datetime import date, timedelta
from unittest import TestCase
from .progression_rules import ACHIEVEMENTS, build_progression, contest_metrics, streaks


class ProgressionRuleTests(TestCase):
    def setUp(self):
        self.today = date(2026, 11, 26)
        self.totals = {'problems': 300, 'lessons': 160, 'courses': 16}

    def test_exactly_thirty_unique_awards(self):
        self.assertEqual(len(ACHIEVEMENTS), 30)
        self.assertEqual(len({a[0] for a in ACHIEVEMENTS}), 30)
        self.assertEqual(Counter(a[1] for a in ACHIEVEMENTS), {0: 8, 1: 8, 2: 5, 3: 5, 4: 4})
        self.assertTrue(all(a[5] > 0 for a in ACHIEVEMENTS))

    def test_empty_and_level_boundaries(self):
        for metrics, xp, level, remainder in [({}, 0, 1, 0), ({'solved': 12}, 240, 1, 240),
                                               ({'solved': 12, 'lessons': 1}, 250, 2, 0),
                                               ({'solved': 50, 'lessons': 20, 'courses': 2, 'contests': 1}, 1450, 6, 200)]:
            result = build_progression(metrics, {}, self.today, self.totals)
            self.assertEqual((result['xp'], result['level'], result['xp_in_level']), (xp, level, remainder))
            self.assertEqual(result['xp_per_level'], 250)
        result = build_progression({}, {}, self.today, self.totals)
        self.assertEqual(result['unlocked_count'], 0)
        self.assertEqual(result['current_streak'], 0)
        self.assertEqual(result['longest_streak'], 0)

    def test_streaks_and_gaps(self):
        day = self.today
        days = [day-timedelta(days=i) for i in [12,11,10,9,8,2,1]]
        self.assertEqual(streaks(days, day), (2, 5))
        self.assertEqual(streaks(days + [day, day, day+timedelta(days=1)], day), (3, 5))
        self.assertEqual(streaks(days, day+timedelta(days=1)), (0, 5))
        self.assertEqual(streaks([], day), (0, 0))

    def test_heatmap_dates_and_achievement_thresholds(self):
        day = self.today
        result = build_progression({'solved': 10, 'lessons': 1}, {day: 3, day-timedelta(days=139): 1, day-timedelta(days=140): 9}, day, self.totals)
        self.assertEqual(len(result['heatmap']), 140)
        self.assertEqual(result['heatmap'][0]['date'], (day-timedelta(days=139)).isoformat())
        self.assertEqual(result['heatmap'][-1], {'date': day.isoformat(), 'count': 3})
        self.assertEqual(sum(r['count'] for r in result['heatmap']), 4)
        self.assertEqual({a['id'] for a in result['achievements'] if a['unlocked']}, {'solve_1', 'solve_5', 'solve_10', 'lesson_1'})

    def test_contest_rank_with_ties_penalties_and_no_points(self):
        rows = [(1,'me',10,5),(1,'x',10,5),(1,'y',10,6),
                (2,'me',10,5),(2,'x',10,4),(2,'y',11,9),(2,'z',12,1),
                (3,'me',0,0),(3,'x',0,0), (4,'me',5,2),(4,'x',8,0)]
        self.assertEqual(contest_metrics(rows,'me'), {'contests':3,'wins':1,'podiums':2})
        self.assertEqual(contest_metrics(rows,'other'), {'contests':0,'wins':0,'podiums':0})

    def test_all_awards_reachable(self):
        metrics = {'solved': 300, 'lessons': 160, 'courses': 16, 'python': 1, 'contests': 10, 'podiums': 1, 'wins': 1,
                   'medium': 10, 'hard': 10, 'expert': 5, 'difficulty_count': 5}
        daily = {self.today-timedelta(days=i):1 for i in range(100)}
        result = build_progression(metrics, daily, self.today, self.totals)
        self.assertEqual(result['unlocked_count'], 30)
        self.assertEqual(result['current_streak'], 100)
        self.assertEqual(result['rank'], 'Их мастер')
        self.assertEqual(result['xp'], 9700)
