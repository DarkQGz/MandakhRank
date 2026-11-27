import json
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.test import TestCase, Client
from django.utils import timezone
from .models import (AccessToken, ClassroomTeacher, Classroom, ClassroomMember, ClassroomAssignment,
                     Course, Lesson, Problem, LessonCompletion, CourseCompletion, Submission, ProjectAttempt)
from .classrooms import teacher


class ClassroomTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        users = get_user_model().objects
        cls.t = users.create_user(username='teacher')
        cls.s = users.create_user(username='student')
        cls.o = users.create_user(username='outsider', is_staff=True)
        cls.admin = users.create_superuser(username='root', password='test-only-password')
        ClassroomTeacher.objects.create(user=cls.t)
        for u, key in [(cls.t, 't'), (cls.s, 's'), (cls.o, 'o'), (cls.admin, 'a')]:
            AccessToken.objects.create(user=u, key=key*64)
        cls.course = Course.objects.create(title='Python-ийн үндэс', tag='Python', level='Анхан шат', description='Test', published=True)
        cls.lesson = Lesson.objects.create(course=cls.course, title='Lesson', published=True)
        cls.hidden = Lesson.objects.create(course=cls.course, title='Hidden', published=False)
        cls.problem = Problem.objects.create(title='Problem', description='Test', published=True, sample_input='', sample_output='')
        cls.c = Classroom.objects.create(owner=cls.t, name='Class', join_code='A'*16)
        ClassroomMember.objects.create(classroom=cls.c, user=cls.s)

    def req(self, key, path='', data=None):
        url = '/api/classrooms/'+path
        kwargs = {'HTTP_AUTHORIZATION': 'Bearer '+key*64}
        if data is None:
            return self.client.get(url, **kwargs)
        return self.client.post(url, data=json.dumps(data), content_type='application/json', **kwargs)

    @property
    def path(self): return f'{self.c.pk}/'

    def assign(self, kind='lesson', target=None, **extra):
        return self.req('t', self.path, dict(action='assign', title='Test task', kind=kind, target_id=target or self.lesson.pk, **extra))

    def test_teacher_role_and_create(self):
        self.assertTrue(teacher(self.t))
        self.assertFalse(teacher(self.o))
        self.assertTrue(teacher(self.admin))
        for k in ('s', 'o'):
            self.assertEqual(self.req(k, data={'action':'create','name':'No'}).status_code,403)
        self.assertEqual(self.req('t', data={'action':'create','name':'New class'}).status_code,201)
        self.assertEqual(self.req('a', data={'action':'create','name':'Admin class'}).status_code,201)
        self.assertEqual(self.client.get('/api/classrooms/').status_code,401)

    def test_membership_and_code_privacy(self):
        self.assertEqual(self.req('o', self.path).status_code,404)
        self.assertNotIn('join_code', self.req('s', self.path).json()['classroom'])
        self.assertIn('join_code', self.req('t', self.path).json()['classroom'])
        for _ in range(2):
            self.assertEqual(self.req('o', data={'action':'join','code':'a'*16}).status_code,200)
        self.assertEqual(self.c.members.filter(user=self.o).count(),1)
        self.assertEqual(self.req('o', self.path, {'action':'rotate'}).status_code,403)
        self.assertEqual(self.req('o', self.path, {'action':'leave'}).status_code,200)
        self.assertEqual(self.req('o', self.path).status_code,404)

    def test_rotate_archive_and_reopen(self):
        self.assertEqual(self.req('t', self.path, {'action':'rotate'}).status_code,200)
        self.c.refresh_from_db()
        self.assertNotEqual(self.c.join_code,'A'*16)
        self.assertEqual(self.req('o', data={'action':'join','code':'A'*16}).status_code,404)
        self.assertEqual(self.req('t', self.path, {'action':'archive'}).status_code,200)
        self.assertEqual(self.req('o', data={'action':'join','code':self.c.join_code}).status_code,404)
        self.assertEqual(self.assign().status_code,409)
        self.assertEqual(self.req('t', self.path, {'action':'reopen'}).status_code,200)
        self.assertEqual(self.req('o', data={'action':'join','code':self.c.join_code}).status_code,200)

    def test_assignment_validation_and_targets(self):
        targets=self.req('t','targets/').json()['targets']
        self.assertNotIn(self.hidden.pk,[x['id'] for x in targets['lesson']])
        self.assertEqual(self.req('s','targets/').status_code,403)
        self.assertEqual(self.assign(target=self.hidden.pk).status_code,404)
        self.assertEqual(self.assign(kind='invalid').status_code,400)
        self.assertEqual(self.assign(due_at='2026-01-01').status_code,400)
        self.assertEqual(self.assign(due_at=(timezone.now()-timedelta(days=1)).isoformat()).status_code,400)
        self.assertEqual(self.assign(due_at=(timezone.now()+timedelta(days=1)).isoformat()).status_code,201)
        self.assertEqual(self.req('s',self.path,{'action':'assign'}).status_code,403)

    def test_real_completion_and_student_privacy(self):
        LessonCompletion.objects.create(user=self.s, lesson=self.lesson)
        self.assertEqual(self.assign().status_code,201)
        self.assertEqual(self.assign('course',self.course.pk).status_code,201)
        self.assertEqual(self.assign('problem',self.problem.pk).status_code,201)
        CourseCompletion.objects.create(user=self.s, course=self.course, score=90)
        Submission.objects.create(user=self.s,problem=self.problem,code='private code',status='Accepted')
        student=self.req('s', self.path).json()['classroom']
        self.assertNotIn('members',student)
        states={a['kind']:a['status'] for a in student['assignments']}
        self.assertEqual(states,{'lesson':'prior','course':'done','problem':'done'})
        self.assertTrue(all('results' not in a for a in student['assignments']))
        teacher_data=self.req('t', self.path).json()['classroom']
        self.assertEqual(len(teacher_data['members']),1)
        self.assertNotIn('private code',json.dumps(teacher_data))
        self.assertEqual(self.req('s',self.path+'report/').status_code,404)
        report=self.req('t',self.path+'report/').json()['csv']
        self.assertIn('student',report)
        self.assertNotIn('private code',report)
        self.assertNotIn('outsider',report)

    def test_archive_remove_and_role_revocation(self):
        self.assertEqual(self.assign().status_code,201)
        a=ClassroomAssignment.objects.get(classroom=self.c)
        l=LessonCompletion.objects.create(user=self.s,lesson=self.lesson)
        self.assertEqual(self.req('t',self.path,{'action':'archive_assignment','assignment_id':a.pk}).status_code,200)
        self.assertEqual(self.req('s',self.path).json()['classroom']['assignments'],[])
        self.assertEqual(self.req('t',self.path,{'action':'remove_member','user_id':self.s.pk}).status_code,200)
        self.assertTrue(LessonCompletion.objects.filter(pk=l.pk).exists())
        self.assertEqual(self.req('s',self.path).status_code,404)
        ClassroomTeacher.objects.filter(user=self.t).delete()
        self.assertEqual(self.req('t',self.path).status_code,404)
        self.assertEqual(self.req('t',self.path+'report/').status_code,404)

    def test_role_admin_only(self):
        client=Client()
        client.force_login(self.o)
        self.assertEqual(client.get('/admin/catalog/classroomteacher/add/').status_code,403)
        client.force_login(self.admin)
        self.assertEqual(client.get('/admin/catalog/classroomteacher/add/').status_code,200)
        self.assertEqual(client.post('/admin/catalog/classroomteacher/add/', {'user':self.o.pk,'_save':'Save'}).status_code,302)
        self.assertTrue(teacher(self.o))

    def test_project_result_and_unavailable_material(self):
        self.assertEqual(self.assign('project',self.course.pk).status_code,201)
        self.assertEqual(self.assign('lesson',self.lesson.pk).status_code,201)
        from .projects import bank
        row=bank()[self.course.title]
        sub=Submission.objects.create(user=self.s,problem=self.problem,code='private',status='Accepted',total=len(row['tests']),passed=len(row['tests']))
        ProjectAttempt.objects.create(user=self.s,course=self.course,project_key=row['key'],mode='python',submission=sub)
        self.lesson.published=False
        self.lesson.save(update_fields=['published'])
        states={a['kind']:a['status'] for a in self.req('s',self.path).json()['classroom']['assignments']}
        self.assertEqual(states,{'lesson':'unavailable','project':'done'})
