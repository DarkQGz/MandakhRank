"""Django integration tests. Run: python manage.py test catalog.test_docker_pull"""
import json
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from .models import Problem, Submission, TestCase as SecretTestCase


@override_settings(JUDGE_ENGINE='docker_pull', JUDGE_WORKER_TOKEN='local-test-token')
class DockerPullTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='docker-test', password='testing-password')
        self.problem = Problem.objects.create(
            title='Addition', description='Add', sample_input='3 7',
            sample_output='10', published=True, cms_task_name='')
        SecretTestCase.objects.create(problem=self.problem, stdin='3 7\n', expected='10\n')
        self.submission = Submission.objects.create(
            user=self.user, problem=self.problem, code='print(sum(map(int, input().split())))',
            status='Queued', total=1, test_snapshot=[{'stdin': '3 7\n', 'expected': '10\n'}])
        self.auth = {'HTTP_AUTHORIZATION': 'Bearer local-test-token'}

    def post(self, action, body=None, authenticated=True):
        return self.client.post('/api/judge/' + action + '/',
                                data=json.dumps(body if body is not None else {}),
                                content_type='application/json',
                                **(self.auth if authenticated else {}))

    def test_status_requires_auth_and_is_docker_pull(self):
        self.assertEqual(self.post('status', authenticated=False).status_code, 401)
        self.assertEqual(self.post('status').json(), {'engine': 'docker_pull', 'protocol': 'docker-tests-v1'})

    def test_no_auth_no_hidden_tests(self):
        self.assertEqual(self.post('claim', authenticated=False).status_code, 401)

    def test_claim_returns_hidden_tests_without_cms_mapping(self):
        resp = self.post('claim')
        self.assertEqual(resp.status_code, 200)
        job = resp.json()['job']
        self.assertEqual(job['tests'], [{'stdin': '3 7\n', 'expected': '10\n'}])
        self.assertEqual(job['task_name'], '')
        self.assertEqual(job['expected_tests'], 1)
        self.assertEqual(self.post('complete', {'id': job['id'], 'claim_key': job['claim_key'],
                                                'status': 'Accepted', 'passed': 1, 'total': 1}).status_code, 200)
        self.submission.refresh_from_db()
        self.assertEqual(self.submission.status, 'Accepted')

    def test_public_submission_history_never_leaks_tests(self):
        # /api/submissions/ uses a separate, browser-facing user token. The
        # private worker payload must not be reused in its response.
        from .models import AccessToken
        AccessToken.objects.create(key='a'*64, user=self.user)
        response = self.client.get('/api/submissions/', HTTP_AUTHORIZATION='Bearer ' + 'a'*64)
        self.assertEqual(response.status_code, 200)
        self.assertNotIn('test_snapshot', response.content.decode())
        self.assertNotIn('3 7\\n', response.content.decode())

    def test_rejected_invalid_claim(self):
        self.assertEqual(self.post('heartbeat').status_code, 400)
