import json
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from .models import AccessToken, Problem, Submission, TestCase as HiddenCase
from .judge_languages import LANGUAGES, claim_languages


@override_settings(JUDGE_ENGINE='docker_pull', JUDGE_WORKER_TOKEN='phase6-worker', JUDGE_MULTILANGUAGE_ENABLED=True)
class LanguageQueueTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='phase6-student', password='not-used-123')
        AccessToken.objects.create(user=self.user, key='a'*64)
        self.problem = Problem.objects.create(title='Language test', description='Add', published=True)
        HiddenCase.objects.create(problem=self.problem, stdin='3 7\n', expected='10\n')
        self.browser = {'HTTP_AUTHORIZATION': 'Bearer ' + 'a'*64}
        self.worker = {'HTTP_AUTHORIZATION': 'Bearer phase6-worker'}

    def submit(self, **extra):
        return self.client.post('/api/submissions/', data=json.dumps({'problem_id': self.problem.pk, 'code': 'source', **extra}), content_type='application/json', **self.browser)

    def judge(self, action, data=None):
        return self.client.post('/api/judge/'+action+'/', data=json.dumps(data or {}), content_type='application/json', **self.worker)

    def test_legacy_claim_never_gets_cpp_and_new_worker_can(self):
        self.assertEqual(self.submit(language='cpp').status_code, 201)
        self.assertEqual(self.submit().status_code, 201)
        old = self.judge('claim').json()['job']
        self.assertEqual(old['language'], 'python')
        self.assertIsNone(self.judge('claim').json()['job'])
        new = self.judge('claim', {'languages': list(LANGUAGES)}).json()['job']
        self.assertEqual(new['language'], 'cpp')
        self.assertEqual(new['expected_tests'], 1)
        self.assertEqual(self.judge('complete', {'id': new['id'], 'claim_key': new['claim_key'], 'status': 'Accepted', 'passed': 2, 'total': 2}).status_code, 400)
        self.assertEqual(self.judge('complete', {'id': new['id'], 'claim_key': new['claim_key'], 'status': 'Accepted', 'passed': 1, 'total': 1}).status_code, 200)

    def test_admission_allowlist_and_history(self):
        for invalid in ['ruby', '', None, [], 1, 'C++']:
            self.assertEqual(self.submit(language=invalid).status_code, 400)
        self.assertEqual(self.submit(language='c', code='bad\x00code').status_code, 400)
        self.assertEqual(self.submit(language='java', code='\ud800').status_code, 400)
        self.assertEqual(self.submit(language='java').status_code, 201)
        history = self.client.get('/api/submissions/', **self.browser).json()
        self.assertEqual(history['languages'], list(LANGUAGES))
        self.assertEqual(history['results'][0]['language'], 'java')
        self.assertNotIn('test_snapshot', history['results'][0])
        self.assertNotIn('code', history['results'][0])

    @override_settings(JUDGE_MULTILANGUAGE_ENABLED=False)
    def test_feature_off_preserves_python_and_can_drain_queued_jobs(self):
        self.assertEqual(self.submit(language='cpp').status_code, 409)
        self.assertEqual(self.submit().status_code, 201)
        self.assertEqual(self.client.get('/api/submissions/', **self.browser).json()['languages'], ['python'])
        Submission.objects.create(user=self.user, problem=self.problem, language='c', code='source', total=1, test_snapshot=[{'stdin':'3 7\n','expected':'10\n'}])
        self.assertEqual(self.judge('claim', {'languages':['c']}).json()['job']['language'], 'c')

    def test_invalid_worker_capability_does_not_claim(self):
        self.assertEqual(self.submit().status_code, 201)
        for invalid in [[], 'python', ['ruby'], ['python', 'python'], [None]]:
            self.assertEqual(self.judge('claim', {'languages':invalid}).status_code, 400)
        self.assertEqual(Submission.objects.get(user=self.user).status, 'Queued')
        self.assertEqual(claim_languages({'languages':['cpp']}, 'cms_pull'), ['python'])

    @override_settings(JUDGE_ENGINE='cms_pull')
    def test_other_engines_cannot_accept_non_python(self):
        self.assertEqual(self.submit(language='cpp').status_code, 409)
        self.assertEqual(self.client.get('/api/submissions/', **self.browser).json()['languages'], ['python'])
