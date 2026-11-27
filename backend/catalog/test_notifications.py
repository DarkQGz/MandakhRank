import json
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from .models import (AccessToken, Announcement, NotificationRead, Classroom, ClassroomMember,
                     ClassroomTeacher, ClassroomAssignment, Problem, Submission, Contest, ContestProblem, Course, ProjectAttempt)


class NotificationTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        U = get_user_model()
        for n, k in [('teacher','t'),('other_teacher','o'),('student','s'),('outsider','x'),('admin','a')]:
            u = U.objects.create_user(username=n, is_superuser=n=='admin', is_staff=n=='admin')
            setattr(cls,n,u)
            AccessToken.objects.create(user=u,key=k*64)
        ClassroomTeacher.objects.create(user=cls.teacher)
        ClassroomTeacher.objects.create(user=cls.other_teacher)
        cls.room = Classroom.objects.create(owner=cls.teacher, name='Room A', join_code='NOTIFICATION1')
        ClassroomMember.objects.create(classroom=cls.room,user=cls.student)
        cls.problem = Problem.objects.create(title='Sum',published=True,points=10)

    def req(self, key, route='notifications/', body=None):
        auth = {} if key is None else {'HTTP_AUTHORIZATION':'Bearer '+key*64}
        path='/api/'+route
        if body is None: return self.client.get(path,**auth)
        return self.client.post(path,json.dumps(body),content_type='application/json',**auth)

    def publish(self,key='t',cid='room',**kw):
        data=dict(action='publish',classroom_id=self.room.pk if cid=='room' else cid,title='Exam notice',body='Read chapter 1')
        data.update(kw)
        return self.req(key,'announcements/',data)

    def items(self,key='s'):
        r=self.req(key)
        self.assertEqual(r.status_code,200,r.content)
        return r.json()['results']

    def test_announcement_permissions(self):
        self.assertEqual(self.req(None).status_code,401)
        self.assertEqual(self.req('s','announcements/').status_code,403)
        self.assertEqual(self.publish('s').status_code,403)
        self.assertEqual(self.publish('o').status_code,404)
        self.assertEqual(self.publish('t',None).status_code,403)
        self.assertEqual(self.publish('t',True).status_code,400)
        self.assertEqual(self.publish('t',body=' ').status_code,400)
        self.assertEqual(self.publish('t',title='a'*121).status_code,400)
        self.assertEqual(self.publish().status_code,201)
        self.assertEqual(self.publish('a',None,title='Global').status_code,201)
        self.assertEqual({e['title'] for e in self.items()}, {'Exam notice','Global'})
        self.assertEqual({e['title'] for e in self.items('x')}, {'Global'})
        self.assertEqual(self.req('t','announcements/').json()['global_allowed'],False)
        self.assertEqual(self.req('a','announcements/').json()['global_allowed'],True)

    def test_withdrawal_and_membership(self):
        self.publish()
        a=Announcement.objects.get()
        self.assertEqual(self.req('o','announcements/',{'action':'withdraw','id':a.pk}).status_code,404)
        self.assertEqual(len(self.items()),1)
        ClassroomMember.objects.filter(user=self.student).delete()
        self.assertEqual(self.items(),[])
        ClassroomMember.objects.create(classroom=self.room,user=self.student)
        self.assertEqual(len(self.items()),1)
        self.assertEqual(self.req('t','announcements/',{'action':'withdraw','id':a.pk}).status_code,200)
        self.assertEqual(self.items(),[])

    def test_assignment_and_archived_room(self):
        a=ClassroomAssignment.objects.create(classroom=self.room,title='Homework',kind='problem',target_id=self.problem.pk,target_title='Sum')
        self.assertEqual(self.items()[0]['id'],f'assignment:{a.pk}')
        self.assertEqual(self.items('x'),[])
        self.room.archived=True; self.room.save()
        self.assertEqual(self.items(),[])
        self.assertEqual(self.publish().status_code,404)

    def test_read_and_unread_are_account_scoped(self):
        self.publish('a',None)
        item=self.items()[0]['id']
        self.assertEqual(self.req('s','notifications/?summary=1').json(),{'unread':1})
        self.assertEqual(NotificationRead.objects.count(),0)
        for _ in range(2):
            r=self.req('s',body={'action':'read','ids':[item]})
            self.assertEqual(r.status_code,200); self.assertEqual(r.json()['unread'],0)
        self.assertEqual(NotificationRead.objects.count(),1)
        self.assertEqual(self.req('x','notifications/?summary=1').json(),{'unread':1})
        self.assertEqual(self.req('s',body={'action':'unread','ids':[item]}).json()['unread'],1)

    def test_forged_keys_and_snapshot_mark_all(self):
        self.publish()
        first=self.items()[0]['id']
        self.assertEqual(self.req('x',body={'action':'read','ids':[first]}).status_code,409)
        self.assertEqual(self.req('s',body={'action':'read','ids':[first,'missing']}).status_code,409)
        self.assertEqual(NotificationRead.objects.count(),0)
        self.publish(title='Later')
        self.assertEqual(self.req('s',body={'action':'read','ids':[first]}).json()['unread'],1)
        self.assertEqual(self.req('s',body={'action':'read','ids':[first,first]}).status_code,400)

    def test_verdict_no_code_or_tests(self):
        s=Submission.objects.create(user=self.student,problem=self.problem,code='SECRET_CODE',test_snapshot=[{'stdin':'SECRET_TEST'}],status='Accepted',passed=1,total=1)
        Submission.objects.create(user=self.outsider,problem=self.problem,code='other',status='Wrong Answer')
        Submission.objects.create(user=self.student,problem=self.problem,code='waiting',status='Queued')
        r=self.req('s'); self.assertEqual(r['Cache-Control'],'no-store')
        self.assertNotIn('SECRET_CODE',r.content.decode()); self.assertNotIn('SECRET_TEST',r.content.decode())
        self.assertEqual([e['id'] for e in r.json()['results']],[f'submission:{s.pk}:Accepted'])
        self.assertEqual(self.items('x')[0]['verdict'],'Wrong Answer')
        self.problem.published=False;self.problem.save()
        self.assertEqual(self.items(),[])

    def test_contest_and_private_transport(self):
        now=timezone.now()
        c=Contest.objects.create(title='Contest', starts_at=now-timedelta(minutes=1),ends_at=now+timedelta(hours=1),published=True,auto_judge=True)
        p=Problem.objects.create(title='__contest_private',is_contest_transport=True,published=False,points=0)
        ContestProblem.objects.create(contest=c,label='A',title='Visible task',statement='Add',judge_problem=p,judge_tests=[{'stdin':'SECRET_TEST'}])
        Submission.objects.create(user=self.student,problem=p,code='SECRET_CODE',status='Accepted',passed=1,total=1)
        r=self.req('s'); self.assertNotIn('__contest_private',r.content.decode()); self.assertNotIn('SECRET_TEST',r.content.decode())
        self.assertEqual({e['kind'] for e in r.json()['results']},{'contest','verdict'})
        c.published=False;c.save()
        self.assertEqual(self.items(),[])

    def test_manual_project_review_and_age(self):
        course=Course.objects.create(title='SQL',published=True)
        ProjectAttempt.objects.create(user=self.student,course=course,project_key='sql',mode='review',review_status='approved',reviewed_at=timezone.now(),source='SECRET_SOURCE')
        self.publish('a',None)
        Announcement.objects.update(created_at=timezone.now()-timedelta(days=31))
        r=self.req('s'); self.assertNotIn('SECRET_SOURCE',r.content.decode())
        self.assertEqual([e['title'] for e in r.json()['results']],['Төсөл тэнцсэн'])

    def test_rate_limit_includes_withdrawn(self):
        Announcement.objects.bulk_create([Announcement(author=self.teacher,classroom=self.room,title=str(i),body='x',withdrawn=True) for i in range(10)])
        self.assertEqual(self.publish().status_code,429)
