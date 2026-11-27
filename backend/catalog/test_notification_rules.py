from datetime import datetime, timedelta, timezone
import unittest
from .notification_rules import recent, valid_keys, serialize


class NotificationRulesTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime(2026, 11, 27, tzinfo=timezone.utc)

    def event(self, key, age):
        return {'id': key, 'at': self.now-timedelta(days=age)}

    def test_window_and_future(self):
        items = recent([self.event('old', 31), self.event('boundary', 30), self.event('new', 0), self.event('future', -1)], self.now)
        self.assertEqual([e['id'] for e in items], ['new','boundary'])

    def test_limit_and_deterministic_ties(self):
        events = [self.event(str(i).zfill(3), 1) for i in range(150)]
        out = recent(events+events, self.now)
        self.assertEqual(len(out), 100)
        self.assertEqual((out[0]['id'],out[-1]['id']),('149','050'))

    def test_keys_strict(self):
        for v in (None, {}, [], ['a','a'], [True], [[]], [''], ['x'*97], ['ө'], ['a']*101):
            self.assertFalse(valid_keys(v), repr(v))
        self.assertTrue(valid_keys(['submission:1:Accepted','announcement:2']))

    def test_read_count_only_visible(self):
        out = serialize([self.event('a',0),self.event('b',1)], {'a','outside'})
        self.assertEqual(out['unread'],1)
        self.assertEqual([r['read'] for r in out['results']],[True,False])
        self.assertIsInstance(out['results'][0]['at'],str)
