from django.test import TestCase, override_settings
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.utils import timezone
from datetime import timedelta
from unittest.mock import patch
from .models import Problem, Submission

class RankingTests(TestCase):
    def setUp(self):
        self.a=get_user_model().objects.create_user('alpha')
        self.b=get_user_model().objects.create_user('beta')
        self.p=Problem.objects.create(title='P',points=30,published=True)
    def submit(self,user,status='Accepted',problem=None):
        return Submission.objects.create(user=user,problem=problem or self.p,status=status,code='print(1)',test_snapshot=[{'stdin':'','expected':'1'}],total=1)
    def ranks(self): return self.client.get('/api/rankings/').json()['results']
    def test_no_demo_users_and_zero_score(self):
        self.assertEqual([r['handle'] for r in self.ranks()],['alpha','beta'])
        self.assertEqual([r['rank'] for r in self.ranks()],[1,1])
    def test_repeat_acceptance_counts_once_and_equal_points_sum(self):
        self.submit(self.a);self.submit(self.a)
        q=Problem.objects.create(title='Q',points=30,published=True)
        self.submit(self.a,problem=q);self.submit(self.b,'Wrong Answer')
        rows=self.ranks()
        self.assertEqual((rows[0]['score'],rows[0]['solved']),(60,2))
        self.assertEqual(rows[1]['score'],0)
    def test_excludes_hidden_inactive_and_staff(self):
        self.submit(self.a)
        self.p.published=False;self.p.save()
        self.b.is_active=False;self.b.save()
        get_user_model().objects.create_user('admin',is_staff=True)
        self.assertEqual(len(self.ranks()),1)
        self.assertEqual(self.ranks()[0]['score'],0)
    @override_settings(JUDGE0_URL='https://judge.invalid')
    @patch('catalog.judge.call')
    def test_worker_automatically_accepts_queued_and_updates_rank(self,call):
        call.side_effect=[{'token':'test'},{'status':{'id':3}}]
        s=self.submit(self.a,'Queued')
        call_command('judge_worker',once=True)
        s.refresh_from_db()
        self.assertEqual(s.status,'Accepted')
        self.assertEqual(self.ranks()[0]['score'],30)
    @override_settings(JUDGE0_URL='https://judge.invalid')
    def test_crashed_submission_recovers(self):
        s=self.submit(self.a,'Running')
        Submission.objects.filter(pk=s.pk).update(updated_at=timezone.now()-timedelta(minutes=6))
        call_command('judge_worker',once=True)
        s.refresh_from_db();self.assertEqual(s.status,'Judge Error')
