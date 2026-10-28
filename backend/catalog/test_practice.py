from unittest.mock import patch
from django.test import TestCase,override_settings
from django.contrib.auth import get_user_model
from .models import Problem,TestCase as Case,Submission,AccessToken
from .judge import evaluate
class PracticeTests(TestCase):
    def setUp(self):
        self.user=get_user_model().objects.create_user('testuser',password='strong-password-826')
        AccessToken.objects.create(key='test-token',user=self.user)
        self.headers={'HTTP_AUTHORIZATION':'Bearer test-token'}
        self.p=Problem.objects.create(title='Sum',description='Sum',sample_input='1 2',sample_output='3',published=True)
        Case.objects.create(problem=self.p,stdin='hidden input',expected='secret output')
    def test_hidden_tests(self):
        data=self.client.get('/api/problems/',**self.headers).content.decode()
        self.assertNotIn('secret output',data);self.assertNotIn('hidden input',data)
    @override_settings(JUDGE0_URL='http://judge.invalid')
    def test_submission_snapshot_and_privacy(self):
        self.assertEqual(self.client.post('/api/submissions/',data='{}',content_type='application/json').status_code,401)
        r=self.client.post('/api/submissions/',data={'problem_id':self.p.pk,'code':'print(3)'},content_type='application/json',**self.headers)
        self.assertEqual(r.status_code,201)
        self.assertEqual(Submission.objects.get().test_snapshot[0]['expected'],'secret output')
        other=get_user_model().objects.create_user('other')
        AccessToken.objects.create(key='other-token',user=other)
        self.assertEqual(self.client.get('/api/submissions/',HTTP_AUTHORIZATION='Bearer other-token').json()['results'],[])
    def submission(self):
        return Submission.objects.create(user=self.user,problem=self.p,code='print(3)',status='Running',total=1,test_snapshot=[{'stdin':'1 2','expected':'3'}])
    @patch('catalog.judge.call')
    def test_acceptance_and_completion(self,call):
        call.side_effect=[{'token':'x'},{'status':{'id':3}}]
        s=self.submission();evaluate(s);s.refresh_from_db()
        self.assertEqual(s.status,'Accepted')
        self.assertTrue(self.client.get('/api/problems/',**self.headers).json()['results'][0]['completed'])
    @patch('catalog.judge.call')
    def test_wrong_and_timeout(self,call):
        for verdict,status in [(4,'Wrong Answer'),(5,'Time Limit Exceeded'),(11,'Runtime Error')]:
            call.side_effect=[{'token':'x'},{'status':{'id':verdict}}]
            s=self.submission();evaluate(s);s.refresh_from_db();self.assertEqual(s.status,status)
        self.assertFalse(self.client.get('/api/problems/',**self.headers).json()['results'][0]['completed'])
    @patch('catalog.judge.call',side_effect=OSError('unavailable'))
    def test_judge_failure(self,call):
        s=self.submission();evaluate(s);s.refresh_from_db();self.assertEqual(s.status,'Judge Error')
    @override_settings(JUDGE0_URL='')
    def test_missing_service(self):
        r=self.client.post('/api/submissions/',data={'problem_id':self.p.pk,'code':'print(3)'},content_type='application/json',**self.headers)
        self.assertEqual(r.status_code,503);self.assertFalse(Submission.objects.exists())
    def test_login_logout(self):
        r=self.client.post('/api/auth/login/',data={'username':'testuser','password':'strong-password-826'},content_type='application/json')
        self.assertEqual(r.status_code,200)
        token=r.json()['token'];self.client.post('/api/auth/logout/',data={},content_type='application/json',HTTP_AUTHORIZATION='Bearer '+token)
        self.assertFalse(AccessToken.objects.filter(key=token).exists())
