import json
from django.contrib.auth import get_user_model
from django.test import TestCase
from .models import AccessToken, Problem, Submission, ProfileComment


class SocialProfilesTests(TestCase):
    def setUp(self):
        User = get_user_model()
        self.owner = User.objects.create_user(username='owner', email='private@example.org')
        self.author = User.objects.create_user(username='author')
        self.other = User.objects.create_user(username='other')
        self.admin = User.objects.create_user(username='admin', is_staff=True, is_superuser=True)
        self.headers = {}
        for i, user in enumerate((self.owner, self.author, self.other, self.admin), 1):
            key = str(i) * 64
            AccessToken.objects.create(user=user, key=key)
            self.headers[user.pk] = {'HTTP_AUTHORIZATION': 'Bearer ' + key}
        self.url = f'/api/profile/public/{self.owner.pk}/'

    def post(self, body, user=None, url=None):
        return self.client.post(url or self.url, json.dumps(body), content_type='application/json', **(self.headers[user.pk] if user else {}))

    def test_public_profile_and_privacy(self):
        p = Problem.objects.create(title='A', published=True, points=12)
        for _ in range(2):
            Submission.objects.create(user=self.owner, problem=p, status='Accepted', code='secret code')
        r = self.client.get(self.url)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.json()['statistics']['solved'], 1)
        self.assertEqual(r.json()['statistics']['points'], 12)
        self.assertEqual(r.json()['statistics']['submissions'], 2)
        self.assertEqual(r.json()['recent'], [])
        self.assertEqual(r.json()['solutions'], [])
        self.assertFalse(r.json()['is_owner'])
        self.assertNotIn('private@example.org', r.content.decode())
        self.assertNotIn('secret code', r.content.decode())
        self.assertFalse(r.json()['can_comment'])
        self.owner.is_active = False
        self.owner.save()
        self.assertEqual(self.client.get(self.url).status_code, 404)

    def test_same_dashboard_payload_and_private_problem_filter(self):
        public = Problem.objects.create(title='Published task', published=True, points=12)
        private = Problem.objects.create(title='Private draft', published=False, points=99)
        for i in range(8):
            Submission.objects.create(user=self.owner, problem=public, status='Wrong Answer', code='private code', passed=1, total=4)
        latest = Submission.objects.create(user=self.owner, problem=public, status='Accepted', code='private code', passed=4, total=4)
        Submission.objects.create(user=self.owner, problem=private, status='Accepted', code='private code')
        other = self.client.get(self.url, **self.headers[self.other.pk]).json()
        self.assertEqual(other['statistics']['submissions'], 9)
        self.assertEqual(len(other['activity']), 28)
        self.assertEqual(sum(day['count'] for day in other['activity']), 9)
        self.assertEqual(other['activity'][-1]['count'], 9)
        self.assertEqual(other['statistics']['points'], 12)
        self.assertEqual(other['recent'], [])
        self.assertEqual(other['solutions'], [])
        self.assertNotIn('email', other)
        self.assertNotIn('private code', str(other))
        self.assertNotIn('Private draft', str(other))
        self.assertFalse(other['is_owner'])
        own = self.client.get(self.url, **self.headers[self.owner.pk]).json()
        me = self.client.get('/api/profile/me/', **self.headers[self.owner.pk]).json()
        self.assertTrue(own['is_owner'])
        self.assertEqual(own['email'], self.owner.email)
        self.assertEqual(own['statistics']['submissions'], 10)
        self.assertEqual(len(own['recent']), 6)
        self.assertEqual(own['recent'][1]['id'], latest.pk)
        self.assertEqual(own['recent'][1]['passed'], 4)
        self.assertEqual(own['recent'][1]['total'], 4)
        self.assertIn('created_at', own['recent'][1])
        self.assertEqual(sum(day['count'] for day in own['activity']), 10)
        for field, value in me.items():
            self.assertEqual(own[field], value)

    def test_post_auth_validation_and_author_identity(self):
        self.assertEqual(self.post({'body': 'Сайн байна'}).status_code, 401)
        for body in ['', '  ', 'x'*501, 123, '\x00', '\ud800']:
            self.assertEqual(self.post({'body': body}, self.author).status_code, 400)
        r = self.post({'body': ' Сайн байна! ', 'author_id': self.owner.pk}, self.author)
        self.assertEqual(r.status_code, 201)
        obj = ProfileComment.objects.get(pk=r.json()['id'])
        self.assertEqual(obj.author, self.author)
        self.assertEqual(obj.body, 'Сайн байна!')
        self.assertTrue(self.client.get(self.url, **self.headers[self.owner.pk]).json()['comments'][0]['can_delete'])
        self.assertFalse(self.client.get(self.url, **self.headers[self.other.pk]).json()['comments'][0]['can_delete'])

    def test_delete_permissions_and_scope(self):
        for user in (self.author, self.owner, self.admin):
            c = ProfileComment.objects.create(owner=self.owner, author=self.author, body='hello')
            url = f'{self.url}comments/{c.pk}/delete/'
            self.assertEqual(self.post({}, None, url).status_code, 401)
            self.assertEqual(self.post({}, self.other, url).status_code, 403)
            self.assertEqual(self.post({}, user, f'/api/profile/public/{self.other.pk}/comments/{c.pk}/delete/').status_code, 404)
            self.assertEqual(self.post({}, user, url).status_code, 200)
            self.assertFalse(ProfileComment.objects.filter(pk=c.pk).exists())

    def test_rate_limit_survives_deleting_comments(self):
        for _ in range(10):
            self.assertEqual(self.post({'body': 'hi'}, self.author).status_code, 201)
        ProfileComment.objects.all().delete()
        self.assertEqual(self.post({'body': 'hi'}, self.author).status_code, 429)

    def test_cursor_pagination(self):
        for i in range(23):
            ProfileComment.objects.create(owner=self.owner, author=self.author, body=str(i))
        first = self.client.get(self.url).json()
        second = self.client.get(self.url, {'before': first['next_before']}).json()
        self.assertEqual(len(first['comments']), 20)
        self.assertEqual(len(second['comments']), 3)
        self.assertIsNone(second['next_before'])
        self.assertFalse({c['id'] for c in first['comments']} & {c['id'] for c in second['comments']})
        self.assertEqual(self.client.get(self.url, {'before': 'bad'}).status_code, 400)
