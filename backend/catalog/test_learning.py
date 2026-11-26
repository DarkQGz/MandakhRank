import json
from io import StringIO
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase
from .learning import assessment, bank, questions_for, sections
from .models import AccessToken, Course, Lesson, LessonCompletion, CourseCompletion


class LearningTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command('seed_courses_160', stdout=StringIO())
        cls.a = get_user_model().objects.create_user(username='learn_a', email='private@example.org')
        cls.b = get_user_model().objects.create_user(username='learn_b')
        AccessToken.objects.create(user=cls.a, key='a'*64)
        AccessToken.objects.create(user=cls.b, key='b'*64)
        cls.course = Course.objects.get(title='Python-ийн үндэс')
        cls.lesson = cls.course.lessons.first()

    def get(self, path, who='a'):
        return self.client.get(path, **({'HTTP_AUTHORIZATION': 'Bearer ' + who*64} if who else {}))

    def post(self, path, data, who='a'):
        return self.client.post(path, json.dumps(data), content_type='application/json', **({'HTTP_AUTHORIZATION': 'Bearer ' + who*64} if who else {}))

    def path(self, lesson_id):
        return f'/api/learning/{self.course.pk}/quiz/{lesson_id}/'

    def correct(self, lesson_id):
        return {q['id']: q['correct'] for q in assessment(self.course, lesson_id)[0]}

    def test_all_curriculum_assessments(self):
        self.assertEqual(len(bank()), 16)
        self.assertEqual(Lesson.objects.count(), 160)
        prompts = set()
        for l in Lesson.objects.select_related('course'):
            qs = questions_for(l)
            final = questions_for(l, final=True)
            self.assertEqual(len(qs), 2)
            self.assertEqual(len(final), 1)
            self.assertTrue(all(sections(l.content).values()))
            for q in qs + final:
                self.assertEqual(len(set(q['choices'])), 3)
                self.assertIn(q['correct'], range(3))
                self.assertNotIn(q['prompt'], prompts)
                prompts.add(q['prompt'])
        self.assertEqual(len(prompts), 480)

    def test_read_and_auth(self):
        p = f'/api/learning/{self.course.pk}/'
        data = self.get(p, None).json()
        self.assertEqual(data['completed'], 0)
        self.assertEqual(len(data['lessons']), 12)
        self.assertTrue(data['lessons'][0]['theory'])
        self.assertTrue(data['lessons'][0]['example'])
        self.assertFalse(data['final_unlocked'])
        self.assertEqual(self.get(self.path(self.lesson.pk), None).status_code, 401)
        self.assertEqual(self.post(self.path(self.lesson.pk), {'answers': self.correct(self.lesson.pk)}, None).status_code, 401)
        q = self.get(self.path(self.lesson.pk)).json()['questions']
        self.assertEqual(len(q), 2)
        for item in q:
            self.assertEqual(set(item), {'id','prompt','options'})
            self.assertEqual(len(item['options']), 3)
            self.assertTrue(all(set(o) == {'id','text'} for o in item['options']))
        self.assertEqual(self.get(self.path(0)).status_code, 403)

    def test_grading_retry_and_isolation(self):
        path = self.path(self.lesson.pk)
        correct = self.correct(self.lesson.pk)
        self.assertEqual(self.post(path, {'answers': {}}).status_code, 400)
        forged = dict(correct)
        forged[next(iter(forged))] = 'invalid'
        self.assertEqual(self.post(path, {'answers': forged}).status_code, 400)
        wrong = dict(correct)
        q = assessment(self.course, self.lesson.pk)[0][0]
        wrong[q['id']] = next(o['id'] for o in q['options'] if o['id'] != q['correct'])
        self.assertFalse(self.post(path, {'answers': wrong}).json()['passed'])
        self.assertFalse(LessonCompletion.objects.exists())
        self.assertTrue(self.post(path, {'answers': correct, 'user_id': self.b.pk, 'score': 0}).json()['passed'])
        self.assertTrue(self.post(path, {'answers': correct}).json()['passed'])
        self.assertEqual(LessonCompletion.objects.count(), 1)
        self.assertEqual(LessonCompletion.objects.get().user_id, self.a.pk)
        p = f'/api/learning/{self.course.pk}/'
        self.assertEqual(self.get(p).json()['completed'], 1)
        self.assertEqual(self.get(p, 'b').json()['completed'], 0)
        catalog = self.get('/api/courses/').json()['results']
        self.assertEqual(next(r for r in catalog if r['id']==self.course.pk)['learning']['completed'], 1)
        self.assertEqual(self.get('/api/profile/me/').json()['learning']['lessons'], 1)
        public = self.get(f'/api/profile/public/{self.a.pk}/', 'b').json()
        self.assertEqual(public['learning']['lessons'], 1)
        self.assertNotIn('email', public)
        self.assertEqual(self.get('/api/profile/me/', 'b').json()['learning']['lessons'], 0)

    def test_final_gate_and_passing_score(self):
        self.assertEqual(self.post(self.path(0), {'answers': self.correct(0)}).status_code, 403)
        for l in self.course.lessons.all():
            self.assertTrue(self.post(self.path(l.pk), {'answers': self.correct(l.pk)}).json()['passed'])
        self.assertTrue(self.get(f'/api/learning/{self.course.pk}/').json()['final_unlocked'])
        final = self.get(self.path(0)).json()['questions']
        self.assertEqual(len(final), 12)
        self.assertTrue(all(q['id'].endswith('-final') for q in final))
        correct = self.correct(0)
        wrong = dict(correct)
        for q in assessment(self.course, 0)[0][:3]:
            wrong[q['id']] = next(o['id'] for o in q['options'] if o['id'] != q['correct'])
        self.assertFalse(self.post(self.path(0), {'answers': wrong}).json()['passed'])
        self.assertEqual(CourseCompletion.objects.count(), 0)
        almost = dict(correct)
        for q in assessment(self.course, 0)[0][:2]:
            almost[q['id']] = next(o['id'] for o in q['options'] if o['id'] != q['correct'])
        self.assertTrue(self.post(self.path(0), {'answers': almost}).json()['passed'])
        self.assertTrue(self.post(self.path(0), {'answers': correct}).json()['passed'])
        self.assertEqual(CourseCompletion.objects.count(), 1)
        self.assertEqual(CourseCompletion.objects.get().score, 100)
        profile = self.get('/api/profile/me/').json()['learning']
        self.assertEqual(profile['lessons'], 12)
        self.assertEqual(len(profile['completed_lessons']), 12)
        self.assertEqual(profile['courses'], 1)
        self.assertEqual(profile['completed_courses'][0]['title'], self.course.title)
        self.assertEqual(self.get(self.path(0), 'b').status_code, 403)

    def test_unpublished_changed_or_cross_course_content(self):
        other = Lesson.objects.exclude(course=self.course).first()
        self.assertEqual(self.get(self.path(other.pk)).status_code, 404)
        self.lesson.content = 'Custom teacher content'
        self.lesson.save()
        self.assertEqual(self.get(self.path(self.lesson.pk)).status_code, 404)
        self.lesson.published = False
        self.lesson.save()
        rows = self.get(f'/api/learning/{self.course.pk}/').json()['lessons']
        self.assertNotIn(self.lesson.pk, [l['id'] for l in rows])
        self.course.published = False
        self.course.save()
        self.assertEqual(self.get(f'/api/learning/{self.course.pk}/').status_code, 404)
