import json
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.contrib.admin.models import LogEntry
from .models import AccessToken, ClassroomTeacher, Contest, ContestResult, Problem
from .profile import profile_data
from .views import rows

class TeacherHubTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        for name in ('teacher','student','other','staff'):
            u=get_user_model().objects.create_user(username=name, is_staff=name=='staff')
            setattr(cls,name,u)
            AccessToken.objects.create(user=u,key=(name+'0'*64)[:64])
        ClassroomTeacher.objects.create(user=cls.teacher)
        ClassroomTeacher.objects.create(user=cls.other)
        cls.p=Problem.objects.create(title='P',description='Test',published=True,points=10,sample_input='1',sample_output='1')
        cls.h=Problem.objects.create(title='Hidden',description='Hidden',published=False,sample_input='',sample_output='')
    def req(self, name, data=None):
        kw={'HTTP_AUTHORIZATION':'Bearer '+(name+'0'*64)[:64]}
        url='/api/teacher/workspace/'
        return self.client.get(url,**kw) if data is None else self.client.post(url,json.dumps(data),content_type='application/json',**kw)
    def create(self, **overrides):
        data=dict(action='create',title='Contest',description='',delay_minutes=60,duration_minutes=90,problem_ids=[self.p.pk])
        data.update(overrides)
        return self.req('teacher',data)
    def test_permissions(self):
        self.assertEqual(self.client.get('/api/teacher/workspace/').status_code,401)
        for name in ('student','staff'):
            self.assertEqual(self.req(name).status_code,403)
            self.assertEqual(self.req(name,{'action':'create'}).status_code,403)
        self.assertEqual(self.req('teacher').status_code,200)
    def test_public_identity(self):
        self.assertEqual(profile_data(self.teacher)['role'],'teacher')
        self.assertEqual(profile_data(self.student)['role'],'student')
        ranks={r['id']:r for r in rows('rankings')}
        self.assertEqual(ranks[self.teacher.pk]['role'],'teacher')
        self.assertEqual(ranks[self.student.pk]['role'],'student')
        self.assertNotIn(self.staff.pk,ranks)
    def test_create_validation(self):
        for ids in ([self.h.pk],[self.p.pk,self.p.pk],[],[True]):
            self.assertIn(self.create(problem_ids=ids).status_code,(400,404))
        self.assertEqual(self.create(duration_minutes=True).status_code,400)
        self.assertEqual(Contest.objects.count(),0)
    def test_schedule_start_end_and_ownership(self):
        r=self.create(); self.assertEqual(r.status_code,201,r.content)
        cid=r.json()['contest']['id']
        self.assertEqual(rows('contests')[0]['problems'],[])
        self.assertEqual(rows('contests')[0]['organizer'],'teacher')
        self.assertEqual(self.req('other',{'action':'start','contest_id':cid}).status_code,404)
        self.assertEqual(self.req('teacher',{'action':'start','contest_id':cid}).status_code,200)
        self.assertEqual(len(rows('contests')[0]['problems']),1)
        self.assertEqual(self.req('teacher',{'action':'start','contest_id':cid}).status_code,409)
        self.assertEqual(self.req('teacher',{'action':'end','contest_id':cid}).status_code,200)
    def test_result_bounds_and_revocation(self):
        c=self.create(delay_minutes=0).json()['contest']
        d=dict(action='result',contest_id=c['id'],problem_id=c['problems'][0]['id'],username='student',score=10,penalty=2)
        self.assertEqual(self.req('other',d).status_code,404)
        self.assertEqual(self.req('teacher',dict(d,score=11)).status_code,400)
        self.assertEqual(self.req('teacher',dict(d,username='teacher')).status_code,400)
        self.assertEqual(self.req('teacher',d).status_code,200)
        self.assertEqual(self.req('teacher',dict(d,score=8)).status_code,200)
        self.assertEqual(ContestResult.objects.get().score,8)
        self.assertTrue(LogEntry.objects.filter(user=self.teacher, change_message__contains="Teacher verified contest").count() >= 2)
        ClassroomTeacher.objects.filter(user=self.teacher).delete()
        self.assertEqual(self.req('teacher',d).status_code,403)
