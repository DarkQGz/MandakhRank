from datetime import timedelta
from django.test import TestCase
from django.utils import timezone
from django.core.exceptions import ValidationError
from django.contrib.auth import get_user_model
from .models import Course,Lesson,Contest,ContestProblem,ContestResult
class CmsTests(TestCase):
    def setUp(self):
        self.course=Course.objects.create(title='Python',tag='Python',level='Анхан шат',description='Learn',published=True)
        Lesson.objects.create(course=self.course,title='Public',content='Lesson body',published=True)
        Lesson.objects.create(course=self.course,title='Secret',content='Draft body')
        self.contest=Contest.objects.create(title='Round 1',starts_at=timezone.now()+timedelta(hours=1),ends_at=timezone.now()+timedelta(hours=3),published=True)
        self.problem=ContestProblem.objects.create(contest=self.contest,label='A',title='Hidden title',statement='Secret statement')
    def test_course_publication(self):
        Course.objects.create(title='Draft')
        rows=self.client.get('/api/courses/').json()['results']
        self.assertEqual(len(rows),1)
        self.assertEqual(rows[0]['lessons'],['Public'])
        self.assertEqual(rows[0]['lesson_content'][0]['content'],'Lesson body')
    def test_unpublished_course_detail_hidden(self):
        self.course.published=False;self.course.save()
        self.assertEqual(self.client.get(f'/api/courses/{self.course.pk}/').status_code,404)
    def test_contest_embargo(self):
        response=self.client.get('/api/contests/').json()['results'][0]
        self.assertEqual(response['problems'],[])
        self.contest.starts_at=timezone.now()-timedelta(minutes=1);self.contest.save()
        self.assertEqual(len(self.client.get('/api/contests/').json()['results'][0]['problems']),1)
    def test_standings(self):
        self.contest.starts_at=timezone.now()-timedelta(minutes=1);self.contest.save()
        for name,score,penalty in [('a',80,10),('b',100,20),('c',100,5),('d',100,5)]:
            ContestResult.objects.create(problem=self.problem,participant=name,score=score,penalty=penalty)
        rows=self.client.get('/api/contests/').json()['results'][0]['standings']
        self.assertEqual([r['participant'] for r in rows],['c','d','b','a'])
        self.assertEqual([r['rank'] for r in rows],[1,1,3,4])
    def test_validation(self):
        self.contest.ends_at=self.contest.starts_at
        with self.assertRaises(ValidationError): self.contest.full_clean()
        with self.assertRaises(ValidationError): ContestResult(problem=self.problem,participant='a',score=101).full_clean()
    def test_admin_permissions(self):
        self.assertEqual(self.client.get('/admin/catalog/course/').status_code,302)
        user=get_user_model().objects.create_user('student',password='test-pass')
        self.client.force_login(user)
        self.assertEqual(self.client.get('/admin/catalog/course/').status_code,302)
        user.is_staff=True;user.is_superuser=True;user.save()
        self.assertEqual(self.client.get('/admin/catalog/course/').status_code,200)
    def test_write_api_denied(self):
        self.assertEqual(self.client.post('/api/courses/',{'title':'oops'}).status_code,405)
