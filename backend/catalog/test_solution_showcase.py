import json
from django.contrib.auth import get_user_model
from django.test import TestCase
from .models import AccessToken, Problem, Submission
from .solution_showcase import valid_ids


class ShowcaseTests(TestCase):
    def setUp(self):
        U = get_user_model()
        self.owner = U.objects.create_user(username='show-owner')
        self.other = U.objects.create_user(username='show-other', is_staff=True, is_superuser=True)
        AccessToken.objects.create(user=self.owner, key='a'*64)
        AccessToken.objects.create(user=self.other, key='b'*64)
        self.auth = {'HTTP_AUTHORIZATION': 'Bearer ' + 'a'*64}
        self.other_auth = {'HTTP_AUTHORIZATION': 'Bearer ' + 'b'*64}
        self.p = Problem.objects.create(title='Showcase task', published=True, points=5)
        self.q = Problem.objects.create(title='Another task', published=True, points=5)
        self.a = self.sub(self.p, 'old code')
        self.b = self.sub(self.p, 'print(42)', language='python')
        self.c = self.sub(self.q, 'int main() {}', language='cpp')
        self.fail = self.sub(self.q, 'wrong code', status='Wrong Answer')
        self.foreign = Submission.objects.create(user=self.other, problem=self.p, status='Accepted', code='foreign')
        self.url = '/api/profile/solutions/'
        self.profile = f'/api/profile/public/{self.owner.pk}/'

    def sub(self, problem, code, **kwargs):
        return Submission.objects.create(user=self.owner, problem=problem, code=code,
            test_snapshot=[{'stdin':'SECRET', 'expected':'SECRET'}], **{'status':'Accepted', **kwargs})

    def view(self, s, **headers):
        return self.client.get(f'{self.profile}solutions/{s.pk}/', **headers)

    def save(self, ids, previous=None, auth=None):
        return self.client.post(self.url, json.dumps({'ids':ids, 'previous_ids':previous or []}),
            content_type='application/json', **(self.auth if auth is None else auth))

    def test_private_default_and_owner_preview(self):
        self.assertEqual(self.client.get(self.url).status_code, 401)
        self.assertEqual(self.client.get(self.profile).json()['solutions'], [])
        self.assertEqual(self.client.get(self.profile).json()['recent'], [])
        self.assertEqual(self.view(self.b).status_code, 404)
        self.assertEqual(self.view(self.b, **self.other_auth).status_code, 404)
        self.assertEqual(self.view(self.b, **self.auth).json()['code'], 'print(42)')
        rows = self.client.get(self.url, **self.auth).json()['results']
        self.assertEqual({r['id'] for r in rows}, {self.b.pk, self.c.pk})
        self.assertNotIn('SECRET', str(rows))
        self.assertNotIn('print(42)', str(rows))

    def test_share_selectively_and_revoke(self):
        self.assertEqual(self.save([self.b.pk]).status_code, 200)
        self.assertEqual([r['id'] for r in self.client.get(self.profile).json()['solutions']], [self.b.pk])
        public = self.view(self.b)
        self.assertEqual(public.json()['code'], 'print(42)')
        self.assertEqual(public['Cache-Control'], 'no-store')
        self.assertNotIn('SECRET', public.content.decode())
        self.assertEqual(self.view(self.c).status_code, 404)
        self.assertEqual(self.save([], [self.b.pk]).status_code, 200)
        self.assertEqual(self.view(self.b).status_code, 404)

    def test_invalid_and_stale_changes_atomic(self):
        self.assertEqual(self.save([self.b.pk]).status_code, 200)
        for ids in ([self.foreign.pk], [self.fail.pk], [self.a.pk,self.b.pk], [self.c.pk,self.c.pk], [True]):
            self.assertEqual(self.save(ids, [self.b.pk]).status_code, 400)
        self.assertEqual(self.save([self.c.pk]).status_code, 409)
        self.assertEqual(self.save([], auth={}).status_code, 401)
        self.assertEqual(self.view(self.b).status_code, 200)

    def test_future_code_never_inherits_sharing(self):
        self.assertEqual(self.save([self.b.pk,self.c.pk]).status_code, 200)
        future = self.sub(self.p, 'new private code')
        self.assertEqual(self.view(future).status_code, 404)
        self.assertIn(self.b.pk, {r['id'] for r in self.client.get(self.url, **self.auth).json()['results']})
        self.assertNotIn(future.pk, {r['id'] for r in self.client.get(self.url, **self.auth).json()['results']})
        self.p.published = False
        self.p.save()
        self.assertEqual(self.view(self.b).status_code, 404)
        self.assertEqual(self.save([], [self.b.pk,self.c.pk]).status_code, 200)
        self.p.published = True
        self.p.save()
        self.assertEqual(self.view(self.b).status_code, 404)

    def test_inactive_user_and_project_exclusion(self):
        from .models import Course, ProjectAttempt
        course = Course.objects.create(title='Course')
        project = self.sub(self.q, 'project code')
        ProjectAttempt.objects.create(user=self.owner, course=course, project_key='sample', mode='python', submission=project)
        self.assertEqual(self.save([project.pk]).status_code, 400)
        self.assertEqual(self.view(project, **self.auth).status_code, 404)
        self.assertEqual(self.save([self.c.pk]).status_code, 200)
        self.owner.is_active = False
        self.owner.save()
        self.assertEqual(self.view(self.c).status_code, 404)

    def test_id_validation(self):
        for x in ({}, None, [0], [-1], [True], [1,1], ['1'], [2**63], list(range(1,1002))):
            self.assertFalse(valid_ids(x))
        self.assertTrue(valid_ids([]))
        self.assertTrue(valid_ids([1,2]))
