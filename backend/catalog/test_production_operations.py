import json
from datetime import timedelta
from io import StringIO
from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.db import OperationalError
from django.test import TestCase, override_settings
from django.utils import timezone
from .models import AccessToken, AuthThrottle, Course, Lesson, Problem, Submission, JudgeWorkerState
from .views import rows

@override_settings(JUDGE_ENGINE='docker_pull', JUDGE_WORKER_TOKEN='test-worker-secret', JUDGE_MULTILANGUAGE_ENABLED=True)
class OperationsTests(TestCase):
    def setUp(self):
        U=get_user_model()
        self.user=U.objects.create_user('phase7-user')
        self.staff=U.objects.create_user('phase7-staff',is_staff=True)
        self.admin=U.objects.create_superuser('phase7-admin',email='',password='test-only-password')
    def claim(self,token='test-worker-secret',languages=None):
        return self.client.post('/api/judge/claim/',json.dumps({'languages': languages or ['python']}),content_type='application/json',HTTP_AUTHORIZATION='Bearer '+token)
    def test_health_minimal_and_uncached(self):
        r=self.client.get('/healthz/');self.assertEqual(r.json(),{'status':'ok'});self.assertIn('no-store',r['Cache-Control'])
        with patch('catalog.operations.connection.cursor',side_effect=OperationalError('private database detail')):
            r=self.client.get('/healthz/');self.assertEqual(r.status_code,503);self.assertEqual(r.json(),{'status':'unavailable'})
    def test_admin_only(self):
        self.assertEqual(self.client.get('/admin/operations/').status_code,302)
        self.client.force_login(self.staff);self.assertEqual(self.client.get('/admin/operations/').status_code,403)
        self.client.force_login(self.admin);r=self.client.get('/admin/operations/');self.assertEqual(r.status_code,200);self.assertNotContains(r,'test-worker-secret');self.assertIn('no-store',r['Cache-Control'])
    def test_worker_contact_authenticated_idle_and_throttled(self):
        self.assertEqual(self.claim('bad').status_code,401);self.assertFalse(JudgeWorkerState.objects.exists())
        self.assertEqual(self.claim(languages=['python','cpp']).json(),{'job':None})
        state=JudgeWorkerState.objects.get(engine='docker_pull');self.assertEqual(state.languages,['python','cpp']);seen=state.last_seen
        self.claim(languages=['python','cpp']);state.refresh_from_db();self.assertEqual(state.last_seen,seen)
        self.claim(languages=['python']);state.refresh_from_db();self.assertEqual(state.languages,['python'])
    def test_queue_report_and_result_unchanged(self):
        p=Problem.objects.create(title='phase7 problem',published=True,points=10)
        s=Submission.objects.create(user=self.user,problem=p,code='print(1)',total=1,test_snapshot=[{'stdin':'','expected':'1'}])
        job=self.claim().json()['job'];self.assertEqual(job['id'],s.pk)
        body={'id':s.pk,'claim_key':job['claim_key'],'status':'Accepted','passed':1,'total':1}
        r=self.client.post('/api/judge/complete/',json.dumps(body),content_type='application/json',HTTP_AUTHORIZATION='Bearer test-worker-secret');self.assertEqual(r.status_code,200)
        s.refresh_from_db();self.assertEqual(s.status,'Accepted');self.assertEqual(rows('rankings')[0]['score'],10)
    def test_catalog_prefetch_preserves_order_and_privacy(self):
        for i in range(4):
            c=Course.objects.create(title=f'course {i}',published=True)
            Lesson.objects.create(course=c,title='later',position=2,published=True)
            Lesson.objects.create(course=c,title='first',position=1,published=True)
            Lesson.objects.create(course=c,title='private',position=0,published=False)
        with self.assertNumQueries(2): result=rows('courses')
        self.assertEqual(len(result),4);self.assertTrue(all(c['lessons']==['first','later'] for c in result))
    def test_cache_headers_and_frame_protection(self):
        r=self.client.get('/api/rankings/');self.assertIn('no-store',r['Cache-Control']);self.assertIn('Authorization',r['Vary']);self.assertEqual(r['X-Frame-Options'],'DENY')
        self.assertEqual(self.client.get('/api/profile/me/').status_code,401)
    def test_maintenance_dry_run_and_apply(self):
        old=AccessToken.objects.create(user=self.user,key='a'*64);AccessToken.objects.filter(pk=old.pk).update(created_at=timezone.now()-timedelta(days=8))
        new=AccessToken.objects.create(user=self.user,key='b'*64)
        AuthThrottle.objects.create(key='c'*64,started_at=timezone.now()-timedelta(days=3))
        AuthThrottle.objects.create(key='d'*64)
        call_command('phase7_maintenance',stdout=StringIO());self.assertEqual(AccessToken.objects.count(),2)
        call_command('phase7_maintenance',apply=True,stdout=StringIO());self.assertEqual(list(AccessToken.objects.values_list('pk',flat=True)),[new.pk]);self.assertEqual(AuthThrottle.objects.count(),1)
    def test_malformed_credentials_are_400(self):
        for name in ['a\x00b','a\ud800b']:
            r=self.client.post('/api/auth/login/',json.dumps({'username':name,'password':'example'}),content_type='application/json');self.assertEqual(r.status_code,400)

# SQLite cannot establish PostgreSQL row-locking behavior. Run this only on
# a separate disposable PostgreSQL test database, never the production DB.
from concurrent.futures import ThreadPoolExecutor
from threading import Barrier
from django.db import close_old_connections, connections
from django.test import Client, TransactionTestCase, skipUnlessDBFeature

@override_settings(JUDGE_ENGINE='docker_pull', JUDGE_WORKER_TOKEN='test-worker-secret')
class PostgreSQLClaimTests(TransactionTestCase):
    @skipUnlessDBFeature('has_select_for_update_skip_locked','has_select_for_update_of')
    def test_parallel_workers_claim_distinct_submissions_for_same_problem(self):
        user=get_user_model().objects.create_user('parallel-test')
        p=Problem.objects.create(title='parallel-test problem',published=True)
        ids={Submission.objects.create(user=user,problem=p,code='print(1)',total=1,
             test_snapshot=[{'stdin':'','expected':'1'}]).pk for _ in range(2)}
        gate=Barrier(2,timeout=10)
        def run():
            close_old_connections()
            try:
                gate.wait()
                r=Client().post('/api/judge/claim/',json.dumps({'languages':['python']}),
                    content_type='application/json',HTTP_AUTHORIZATION='Bearer test-worker-secret')
                return r.status_code,r.json()['job']
            finally:connections.close_all()
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(lambda _:run(),range(2)))
        self.assertEqual([r[0] for r in results],[200,200])
        self.assertTrue(all(r[1] is not None for r in results))
        self.assertEqual({r[1]['id'] for r in results},ids)
        self.assertEqual(Submission.objects.filter(pk__in=ids,status='Running').count(),2)
