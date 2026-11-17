import json

from django.contrib.auth import get_user_model
from django.test import TestCase

from .game_questions import QUESTIONS, MAX_ANSWERS
from .models import AccessToken, MiniGameRoom, MiniGameAnswer, MiniGamePlayer


class MiniGamesTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        user_model = get_user_model()
        cls.host = user_model.objects.create_user('host', password='TestPass123!')
        cls.guest = user_model.objects.create_user('guest', password='TestPass123!')
        cls.third = user_model.objects.create_user('third', password='TestPass123!')
        for user in [cls.host, cls.guest, cls.third]:
            AccessToken.objects.create(key=f'{user.username:0<64}', user=user)

    def call(self, user, method, path, body=None):
        headers = {'HTTP_AUTHORIZATION': 'Bearer ' + f'{user.username:0<64}'}
        if method == 'get':
            return self.client.get(path, **headers)
        return self.client.post(path, data=json.dumps(body or {}), content_type='application/json', **headers)

    def make(self, mode='tug', fmt='solo'):
        r = self.call(self.host, 'post', '/api/games/create/', {'mode': mode, 'format': fmt})
        self.assertEqual(r.status_code, 201)
        return r.json()['code']

    def test_create_join_start_scoring_and_no_leaderboard_awards(self):
        code = self.make()
        state = self.call(self.host, 'get', f'/api/games/{code}/').json()
        self.assertEqual(state['status'], 'waiting')
        self.assertIsNone(state['question'])
        start = self.call(self.host, 'post', f'/api/games/{code}/start/')
        self.assertEqual(start.status_code, 409)
        guest = self.call(self.guest, 'post', f'/api/games/{code}/join/')
        self.assertEqual(guest.json()['side'], 2)
        self.assertEqual(self.call(self.host, 'post', f'/api/games/{code}/start/').status_code, 200)
        q = self.call(self.host, 'get', f'/api/games/{code}/').json()['question']
        self.assertNotIn('correct', q)
        self.assertNotIn('answer', q)
        chosen = QUESTIONS['tug'][0][3]
        answer = self.call(self.host, 'post', f'/api/games/{code}/answer/', {'index': q['index'], 'choice': chosen})
        self.assertEqual(answer.status_code, 200)
        self.assertTrue(answer.json()['correct'])
        self.assertEqual(answer.json()['room']['scores'], [1, 0])
        self.assertEqual(MiniGameAnswer.objects.count(), 1)
        self.assertEqual(self.call(self.host, 'post', f'/api/games/{code}/answer/', {'index': 0, 'choice': chosen}).status_code, 409)
        self.assertEqual(self.call(self.third, 'get', f'/api/games/{code}/').status_code, 403)

    def test_solo_capacity_and_team_capacity(self):
        code = self.make()
        self.call(self.guest, 'post', f'/api/games/{code}/join/')
        self.assertEqual(self.call(self.third, 'post', f'/api/games/{code}/join/').status_code, 409)
        team_code = self.make('frog', 'team')
        self.assertEqual(self.call(self.guest, 'post', f'/api/games/{team_code}/join/', {'side': 1}).status_code, 200)
        self.assertEqual(self.call(self.third, 'post', f'/api/games/{team_code}/join/', {'side': 2}).status_code, 200)

    def test_only_host_can_start_and_no_join_after_start(self):
        code = self.make('rocket')
        self.call(self.guest, 'post', f'/api/games/{code}/join/')
        self.assertEqual(self.call(self.guest, 'post', f'/api/games/{code}/start/').status_code, 403)
        self.call(self.host, 'post', f'/api/games/{code}/start/')
        self.assertEqual(self.call(self.third, 'post', f'/api/games/{code}/join/').status_code, 409)

    def test_wrong_answers_do_not_score(self):
        code = self.make('frog')
        self.call(self.guest, 'post', f'/api/games/{code}/join/')
        self.call(self.host, 'post', f'/api/games/{code}/start/')
        wrong = (QUESTIONS['frog'][0][3] + 1) % 4
        r = self.call(self.host, 'post', f'/api/games/{code}/answer/', {'index': 0, 'choice': wrong})
        self.assertEqual(r.status_code, 200)
        self.assertFalse(r.json()['correct'])
        self.assertEqual(r.json()['room']['scores'], [0, 0])
        self.assertEqual(r.json()['room']['my_answers'], 1)

    def test_reject_bad_input_and_unauthorized(self):
        self.assertEqual(self.client.post('/api/games/create/', content_type='application/json', data='{}').status_code, 401)
        self.assertEqual(self.call(self.host, 'post', '/api/games/create/', {'mode': 'invalid', 'format': 'team'}).status_code, 400)
        self.assertEqual(self.call(self.host, 'post', '/api/games/create/', {'mode': 'tug', 'format': 'oops'}).status_code, 400)

    def test_question_bank_integrity(self):
        self.assertEqual(set(QUESTIONS), {'tug', 'frog', 'rocket'})
        for qs in QUESTIONS.values():
            self.assertGreaterEqual(len(qs), MAX_ANSWERS)
            for question in qs:
                self.assertEqual(len(question), 4)
                self.assertEqual(len(question[2]), 4)
                self.assertTrue(0 <= question[3] < 4)
