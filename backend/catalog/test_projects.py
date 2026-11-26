import json
from io import StringIO
from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase, override_settings
from django.utils import timezone
from django.urls import reverse
from .models import AccessToken, Course, CourseCompletion, LessonCompletion, Problem, ProjectAttempt, Submission
from .projects import bank
from .project_admin import ReviewForm


@override_settings(JUDGE_ENGINE='docker_pull', JUDGE_WORKER_TOKEN='project-worker-token')
class ProjectTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        call_command('seed_courses_160', stdout=StringIO())
        cls.a = get_user_model().objects.create_user(username='project-a')
        cls.b = get_user_model().objects.create_user(username='project-b')
        AccessToken.objects.create(user=cls.a, key='a'*64)
        AccessToken.objects.create(user=cls.b, key='b'*64)
        cls.python = Course.objects.get(title='Python-ийн үндэс')
        cls.manual = Course.objects.get(title='Git ба GitHub')

    def path(self, course): return f'/api/learning/{course.pk}/project/'
    def get(self, path, who='a'):
        return self.client.get(path, **({'HTTP_AUTHORIZATION':'Bearer '+who*64} if who else {}))
    def post(self, path, data, who='a'):
        return self.client.post(path, json.dumps(data), content_type='application/json', **({'HTTP_AUTHORIZATION':'Bearer '+who*64} if who else {}))
    def unlock(self, c):
        for l in c.lessons.filter(published=True): LessonCompletion.objects.create(user=self.a, lesson=l)
        CourseCompletion.objects.create(user=self.a, course=c, score=100)
    def worker(self, action, data):
        return self.client.post('/api/judge/'+action+'/', json.dumps(data), content_type='application/json', HTTP_AUTHORIZATION='Bearer project-worker-token')
    def complete(self, good=True):
        job=self.worker('claim',{}).json()['job']
        self.assertEqual(len(job['tests']),9)
        total=job['expected_tests']
        r=self.worker('complete',dict(id=job['id'],claim_key=job['claim_key'],status='Accepted' if good else 'Wrong Answer',passed=total if good else 0,total=total))
        self.assertEqual(r.status_code,200)

    def test_catalog_and_locked_preview(self):
        self.assertEqual(set(bank()),set(Course.objects.values_list('title',flat=True)))
        self.assertEqual(len(bank()),16)
        self.assertEqual(sum(r['mode']=='python' for r in bank().values()),12)
        self.assertEqual(sum(len(r.get('tests',[])) for r in bank().values()),108)
        for course in Course.objects.all():
            data=self.get(self.path(course),None).json()
            self.assertFalse(data['unlocked'])
            self.assertNotIn('tests',data['project'])
            self.assertEqual(data['attempts'],[])
            self.assertIsNone(data['latest_source'])
            self.assertEqual(self.get(f'/api/learning/{course.pk}/').json()['project']['title'],data['project']['title'])
        self.assertEqual(self.post(self.path(self.python),{'source':'print(1)'},None).status_code,401)
        self.assertEqual(self.post(self.path(self.python),{'source':'print(1)'}).status_code,403)
        CourseCompletion.objects.create(user=self.a,course=self.python,score=100)
        self.assertEqual(self.post(self.path(self.python),{'source':'print(1)'}).status_code,403)

    def test_python_queue_and_public_profile_isolation(self):
        self.unlock(self.python)
        path=self.path(self.python)
        before=Problem.objects.filter(published=True).count()
        profile_before=self.get('/api/profile/me/').json()
        for bad in ('', 'a'*20001, 3, '\x00', '\ud800'):
            self.assertEqual(self.post(path,{'source':bad}).status_code,400)
        code='print("private-source")'
        r=self.post(path,{'source':code,'user_id':self.b.pk,'status':'Accepted','passed':True})
        self.assertEqual(r.status_code,201)
        self.assertEqual(r.json()['attempt']['status'],'Queued')
        self.assertFalse(r.json()['attempt']['passed'])
        self.assertEqual(self.post(path,{'source':code}).status_code,409)
        self.assertEqual(self.get(path,'b').json()['attempts'],[])
        self.assertIsNone(self.get(path,'b').json()['latest_source'])
        self.assertEqual(self.get(path).json()['latest_source'],code)
        self.assertEqual(self.get('/api/submissions/').json()['results'],[])
        self.assertEqual(Problem.objects.filter(published=True).count(),before)
        self.complete(False)
        self.assertFalse(self.get(path).json()['completed'])
        self.assertEqual(self.post(path,{'source':code}).status_code,201)
        self.complete(True)
        self.assertTrue(self.get(path).json()['completed'])
        self.assertEqual(self.post(path,{'source':code}).status_code,409)
        own=self.get('/api/profile/me/').json(); pub=self.get(f'/api/profile/public/{self.a.pk}/','b').json()
        self.assertEqual(own['statistics'],profile_before['statistics'])
        self.assertEqual(own['progression']['xp'],profile_before['progression']['xp'])
        self.assertEqual(own['learning']['projects']['count'],1)
        self.assertEqual(pub['learning']['projects'],own['learning']['projects'])
        self.assertNotIn('private-source',str(pub))
        self.assertEqual(self.get('/api/profile/me/','b').json()['learning']['projects']['count'],0)
        self.assertEqual(ProjectAttempt.objects.count(),2)

    def test_manual_review_requires_verified_staff_result(self):
        self.unlock(self.manual)
        path=self.path(self.manual)
        r=self.post(path,{'source':'private evidence','review_status':'approved','reviewed_at':'2026-01-01'})
        self.assertEqual(r.status_code,201)
        self.assertFalse(self.get(path).json()['completed'])
        self.assertFalse(Submission.objects.exists())
        self.assertEqual(self.post(path,{'source':'again'}).status_code,409)
        a=ProjectAttempt.objects.get()
        self.assertFalse(ReviewForm({'review_status':'approved','feedback':' '},instance=a).is_valid())
        a.review_status='rejected'; a.feedback='README дутуу'; a.reviewed_at=timezone.now(); a.save()
        self.assertEqual(self.get(path).json()['attempts'][0]['feedback'],'README дутуу')
        self.assertEqual(self.post(path,{'source':'fixed private evidence'}).status_code,201)
        a=ProjectAttempt.objects.first(); a.review_status='approved'; a.feedback='Шаардлага хангасан'; a.reviewed_at=timezone.now(); a.save()
        self.assertTrue(self.get(path).json()['completed'])
        self.assertEqual(self.get('/api/profile/me/').json()['learning']['projects']['count'],1)
        self.assertNotIn('private evidence',str(self.get(f'/api/profile/public/{self.a.pk}/','b').json()))

    def test_admin_review_workflow_and_permissions(self):
        self.unlock(self.manual)
        self.post(self.path(self.manual), {'source':'<script>alert(1)</script>'})
        attempt=ProjectAttempt.objects.get()
        url=reverse('admin:catalog_projectattempt_change',args=[attempt.pk])
        self.client.force_login(self.b)
        self.assertNotEqual(self.client.post(url,{'review_status':'approved','feedback':'forged'}).status_code,200)
        attempt.refresh_from_db(); self.assertEqual(attempt.review_status,'pending')
        reviewer=get_user_model().objects.create_superuser(username='review-admin',email='review@example.org',password='test-password-only')
        self.client.force_login(reviewer)
        page=self.client.get(url)
        self.assertEqual(page.status_code,200)
        self.assertNotIn('<script>alert(1)</script>',page.content.decode())
        invalid=self.client.post(url,{'review_status':'approved','feedback':'','_save':'Save'})
        self.assertEqual(invalid.status_code,200)
        attempt.refresh_from_db(); self.assertEqual(attempt.review_status,'pending')
        valid=self.client.post(url,{'review_status':'approved','feedback':'Бүх шаардлага хангасан.','_save':'Save'})
        self.assertEqual(valid.status_code,302)
        attempt.refresh_from_db(); self.assertEqual(attempt.review_status,'approved')
        self.assertEqual(attempt.reviewed_by_id,reviewer.pk)
        self.assertIsNotNone(attempt.reviewed_at)
        self.assertTrue(self.get(self.path(self.manual)).json()['completed'])

    @override_settings(JUDGE_ENGINE='cms_pull')
    def test_python_requires_docker(self):
        self.unlock(self.python)
        self.assertEqual(self.post(self.path(self.python),{'source':'print(1)'}).status_code,503)
        self.assertFalse(ProjectAttempt.objects.exists())
