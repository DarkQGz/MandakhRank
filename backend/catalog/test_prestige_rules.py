import unittest
from .prestige_rules import (DEFAULT, REWARDS, appearance_data, effective_preferences,
                             prestige_rank, unlocked_ids, validate_preferences)
from .progression_rules import ACHIEVEMENTS


class PrestigeRulesTests(unittest.TestCase):
    def test_all_achievements_have_unique_frame_designs(self):
        self.assertEqual(set(REWARDS), {a[0] for a in ACHIEVEMENTS})
        self.assertEqual(len(REWARDS), 30)
        self.assertEqual(len({(tuple(r['colors']), r['motif']) for r in REWARDS.values()}), 30)
        for r in REWARDS.values():
            for c in r['colors']:
                self.assertEqual(len(c), 6)
                int(c, 16)

    def test_earned_positive_ranks_only(self):
        for i in range(1, 6):
            self.assertEqual(prestige_rank({'rank': i, 'score': 1}), i)
        for rank in (0, 6, -1, True, '1', None):
            self.assertIsNone(prestige_rank({'rank': rank, 'score': 10}))
        self.assertIsNone(prestige_rank({'rank': 1, 'score': 0}))

    def test_strict_preferences(self):
        valid = dict(DEFAULT, frame='solve_1', accent='solve_1', title='solve_1', featured=['solve_1'])
        self.assertEqual(validate_preferences(valid, {'solve_1'}), valid)
        for update in ({'frame':'solve_300'}, {'accent':'#ffffff'}, {'title':'teacher'}, {'featured':['solve_1']*2},
                       {'featured':['solve_1', 'solve_5']}, {'featured': [['solve_1']]}, {'motion': 1},
                       {'background': ['plain']}, {'user_id': 2}, {'rank':1}, {'role':'teacher'}, {'frame':None}):
            with self.subTest(update=update), self.assertRaises(ValueError):
                validate_preferences(dict(valid, **update), {'solve_1'})
        with self.assertRaises(ValueError):
            validate_preferences({'frame':'solve_1'}, {'solve_1'})
        with self.assertRaises(ValueError):
            validate_preferences(dict(DEFAULT, featured=list(REWARDS)[:4]), set(REWARDS))

    def test_reset_falls_back_without_changing_original(self):
        stored=dict(DEFAULT, frame='solve_1', accent='solve_1', title='solve_5', featured=['solve_1','solve_5'])
        self.assertEqual(effective_preferences(stored, {'solve_1'})['featured'], ['solve_1'])
        self.assertEqual(effective_preferences(stored, set()), DEFAULT)
        self.assertEqual(stored['frame'],'solve_1')
        self.assertEqual(effective_preferences({'featured': [[], 'x'], 'background': []}, set()), DEFAULT)

    def test_public_payload_contains_only_effective_selection(self):
        progress = {'achievements':[{'id':'solve_1','unlocked':True,'progress':1,'target':1},
                                    {'id':'solve_5','unlocked':False,'progress':1,'target':5},
                                    {'id':'not-known','unlocked':True}]}
        self.assertEqual(unlocked_ids(progress),{'solve_1'})
        stored=dict(DEFAULT, frame='solve_1', title='solve_5', featured=['solve_1','solve_5'])
        public=appearance_data(progress,stored,3)
        own=appearance_data(progress,stored,3,owner=True)
        self.assertNotIn('preferences',public);self.assertNotIn('rewards',public)
        self.assertEqual(public['frame']['id'],'solve_1');self.assertIsNone(public['title'])
        self.assertEqual([r['id'] for r in public['featured']],['solve_1'])
        self.assertEqual(len(own['rewards']),30)
        self.assertEqual(sum(r['unlocked'] for r in own['rewards']),1)
        self.assertEqual(own['rank'],3)
