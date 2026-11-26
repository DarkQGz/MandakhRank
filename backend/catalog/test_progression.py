from datetime import datetime, timedelta, timezone as dt_timezone
from unittest.mock import patch
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from .models import (AccessToken, Problem, Submission, Course, Lesson, LessonCompletion,
                     CourseCompletion, Contest, ContestProblem, ContestResult)
from .progression import profile_progression


class ProgressionIntegrationTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='progress', email='private@sample.org')
        self.other = get_user_model().objects.create_user(username='other')
        self.user.date_joined = timezone.now()-timedelta(days=60)
        self.user.save(update_fields=['date_joined'])
        AccessToken.objects.create(user=self.user, key='a'*64)
        AccessToken.objects.create(user=self.other, key='b'*64)
        self.headers = {'HTTP_AUTHORIZATION': 'Bearer '+'a'*64}
        self.problem = Problem.objects.create(title='Public', difficulty='Дунд', published=True, points=23)
        self.private = Problem.objects.create(title='Unpublished secret', difficulty='Хүнд', published=False, points=100)
        self.course = Course.objects.create(title='Python-ийн үндэс', level='Анхан шат', published=True)
        self.lesson = Lesson.objects.create(course=self.course, title='Lesson', published=True)

    def submit(self, problem, status='Accepted', user=None, at=None):
        s=Submission.objects.create(user=user or self.user, problem=problem, status=status, code='secret source')
        if at is not None: Submission.objects.filter(pk=s.pk).update(created_at=at)
        return s

    def test_unique_xp_and_public_profiles(self):
        self.submit(self.problem); self.submit(self.problem)
        self.submit(self.private)
        self.submit(Problem.objects.create(title='Failed', published=True), 'Wrong Answer')
        self.submit(self.problem, user=self.other)
        LessonCompletion.objects.create(user=self.user, lesson=self.lesson)
        CourseCompletion.objects.create(user=self.user, course=self.course, score=90)
        hidden=Lesson.objects.create(course=self.course,title='Private lesson',published=False)
        LessonCompletion.objects.create(user=self.user, lesson=hidden)
        own=self.client.get('/api/profile/me/', **self.headers)
        public=self.client.get(f'/api/profile/public/{self.user.pk}/', HTTP_AUTHORIZATION='Bearer '+'b'*64)
        self.assertEqual(own.status_code,200);self.assertEqual(public.status_code,200)
        a=own.json(); b=public.json()
        self.assertEqual(a['progression'],b['progression'])
        self.assertEqual(a['statistics']['points'],23)
        self.assertEqual(b['statistics']['points'],23)
        self.assertEqual(a['progression']['xp'],130)
        self.assertEqual(a['progression']['solved'],1)
        self.assertEqual(a['progression']['lessons'],1)
        self.assertEqual(a['progression']['courses'],1)
        self.assertEqual(a['progression']['heatmap'][-1]['count'],3)
        self.assertEqual({x['id'] for x in a['progression']['achievements'] if x['unlocked']}, {'solve_1','lesson_1','course_1','python'})
        self.assertNotIn('secret source',public.content.decode())
        self.assertNotIn('Unpublished secret',public.content.decode())
        self.assertNotIn('private@sample.org',public.content.decode())
        # No XP mutation on repeated reads, no extra model writes.
        self.assertEqual(profile_progression(self.user),profile_progression(self.user))
        self.assertEqual(Submission.objects.filter(user=self.user).count(),4)
        self.assertEqual(LessonCompletion.objects.filter(user=self.user).count(),2)

    def test_local_day_and_streak(self):
        now=datetime(2026,11,26,17,0,tzinfo=dt_timezone.utc) # Nov 27 01:00 in UB
        self.submit(self.problem,at=now-timedelta(hours=3)) # Nov 26 22:00
        self.submit(self.problem,at=now-timedelta(minutes=30)) # Nov 27 00:30
        self.submit(self.problem,at=now-timedelta(minutes=20)) # same day
        self.submit(self.problem,at=now+timedelta(hours=1)) # not yet happened
        with patch('catalog.progression.timezone.now', return_value=now):
            result=profile_progression(self.user)
        self.assertEqual(result['current_streak'],2)
        self.assertEqual(result['xp'],20)
        self.assertEqual(result['heatmap'][-2:], [{'date':'2026-11-26','count':1},{'date':'2026-11-27','count':1}])

    def test_contests_only_finished_public_positive_results(self):
        now=timezone.now()
        for title,published,end,score in [('Finished',True,now-timedelta(days=1),50),('Future',True,now+timedelta(days=1),50),('Private',False,now-timedelta(days=1),50),('Zero',True,now-timedelta(days=1),0),('Before account',True,now-timedelta(days=70),50)]:
            c=Contest.objects.create(title=title, published=published, starts_at=end-timedelta(hours=2), ends_at=end)
            p=ContestProblem.objects.create(contest=c,label='A',title='A',points=100)
            ContestResult.objects.create(problem=p,participant=self.user.username,score=score,penalty=10)
            ContestResult.objects.create(problem=p,participant=self.other.username,score=score,penalty=12)
        result=profile_progression(self.user)
        self.assertEqual(result['xp'],50)
        self.assertEqual(result['contests'],1)
        self.assertEqual({a['id'] for a in result['achievements'] if a['unlocked']}, {'contest_1','contest_podium','contest_win'})
