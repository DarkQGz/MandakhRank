import json
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.test import TestCase, override_settings
from django.utils import timezone
from .models import AccessToken, ClassroomTeacher, Contest, Problem, Submission, TestCase as SecretCase
from .contest_live import progression_rows
from .views import rows


@override_settings(JUDGE_ENGINE='docker_pull', JUDGE_WORKER_TOKEN='contest-worker-test', JUDGE_MULTILANGUAGE_ENABLED=True)
class LiveContestTests(TestCase):
    @classmethod
    def setUpTestData(cls):
        for name, key in [('teacher','t'),('student','s'),('other','o')]:
            user=get_user_model().objects.create_user(username=name)
            setattr(cls,name,user)
            AccessToken.objects.create(user=user,key=key*64)
        ClassroomTeacher.objects.create(user=cls.teacher)
        cls.p=Problem.objects.create(title='Sum', description='Add', published=True, points=100, sample_input='1 2', sample_output='3')
        SecretCase.objects.create(problem=cls.p,stdin='private-input',expected='private-expected')

    def auth(self, who):
        return {} if who is None else {'HTTP_AUTHORIZATION':'Bearer '+{'teacher':'t','student':'s','other':'o'}[who]*64}

    def post(self, url, data, who='student'):
        return self.client.post(url,json.dumps(data),content_type='application/json',**self.auth(who))

    def create(self, delay=0, **kwargs):
        data=dict(action='create',title='Round',description='',delay_minutes=delay,duration_minutes=60,problem_ids=[self.p.pk],auto_judge=True)
        data.update(kwargs)
        return self.post('/api/teacher/workspace/',data,'teacher')

    def new(self, delay=0):
        r=self.create(delay)
        self.assertEqual(r.status_code,201,r.content)
        c=Contest.objects.get(pk=r.json()['contest']['id']); p=c.problems.get()
        return c,p,f'/api/contests/{c.pk}/live/',f'/api/contests/{c.pk}/tasks/{p.pk}/submissions/'

    def submit(self, url, p, who='student', **kwargs):
        return self.post(url,dict(problem_id=p.pk,code='print(1)',language='python',**kwargs),who)

    def worker(self, action, body):
        return self.client.post('/api/judge/'+action+'/',json.dumps(body),content_type='application/json',HTTP_AUTHORIZATION='Bearer contest-worker-test')

    def complete(self, verdict='Accepted'):
        job=self.worker('claim',{'languages':['python','cpp']}).json()['job']
        self.assertIsNotNone(job)
        r=self.worker('complete',dict(id=job['id'],claim_key=job['claim_key'],status=verdict,passed=job['expected_tests'] if verdict=='Accepted' else 0,total=job['expected_tests']))
        self.assertEqual(r.status_code,200,r.content)
        return job

    def test_upcoming_hides_tasks_and_auth(self):
        c,p,live,url=self.new(60)
        self.assertEqual(self.client.get(live).json()['problems'],[])
        self.assertEqual(self.client.get(url,**self.auth('student')).status_code,404)
        self.assertEqual(self.submit(url,p).status_code,404)
        self.assertEqual(self.submit(url,p,None).status_code,401)
        self.assertEqual(rows('contests')[0]['problems'],[])

    def test_snapshot_and_private_transport(self):
        c,p,live,url=self.new()
        self.assertFalse(p.judge_problem.published)
        self.assertEqual(p.judge_problem.points,0)
        SecretCase.objects.filter(problem=self.p).update(expected='changed')
        self.assertNotIn('private-expected',self.client.get(live).content.decode())
        with self.assertRaises(IntegrityError),transaction.atomic():
            Problem.objects.filter(pk=p.judge_problem_id).update(published=True)
        self.assertEqual(self.submit(url,p).status_code,201)
        job=self.complete()
        self.assertEqual(job['tests'],[{'stdin':'private-input','expected':'private-expected'}])
        self.assertEqual(self.client.get(live).json()['standings'][0]['score'],100)
        self.assertEqual(self.client.get('/api/submissions/',**self.auth('student')).json()['results'],[])
        self.assertEqual(self.client.get('/api/profile/me/',**self.auth('student')).json()['statistics']['solved'],0)
        self.assertEqual(next(r for r in rows('rankings') if r['id']==self.student.pk)['score'],0)
        self.assertEqual(self.client.get('/api/profile/solutions/',**self.auth('student')).json()['results'],[])
        self.assertEqual(self.client.get(url,**self.auth('other')).json()['results'],[])
        self.assertNotIn('private-input',self.client.get(url,**self.auth('student')).content.decode())

    def test_teacher_cannot_submit_or_set_auto_score(self):
        c,p,live,url=self.new()
        self.assertEqual(self.submit(url,p,'teacher').status_code,403)
        self.assertEqual(self.post('/api/teacher/workspace/',dict(action='result',contest_id=c.pk,problem_id=p.pk,username='student',score=100,penalty=0),'teacher').status_code,409)
        self.assertEqual(self.post(url,dict(problem_id=p.pk+1,code='print(1)',language='python')).status_code,400)
        self.assertEqual(self.post(url,dict(problem_id=p.pk,code='print(1)',language='bad')).status_code,400)

    def test_deadline_drains_and_progression(self):
        c,p,live,url=self.new()
        self.assertEqual(self.submit(url,p).status_code,201)
        # Teacher end synchronizes with admission. In-flight job remains valid.
        r=self.post('/api/teacher/workspace/',dict(action='end',contest_id=c.pk),'teacher')
        self.assertEqual(r.status_code,200,r.content)
        self.assertEqual(self.submit(url,p).status_code,409)
        self.assertFalse(self.client.get(live).json()['final'])
        self.assertEqual(progression_rows(self.student,timezone.now()),[])
        self.complete()
        self.assertTrue(self.client.get(live).json()['final'])
        self.assertEqual(progression_rows(self.student,timezone.now())[0][2],100)

    def test_missing_tests_rolls_back(self):
        SecretCase.objects.filter(problem=self.p).delete()
        self.assertEqual(self.create().status_code,400)
        self.assertFalse(Contest.objects.exists())
        self.assertFalse(Problem.objects.filter(is_contest_transport=True).exists())

    def test_shared_queue_quota(self):
        c,p,live,url=self.new()
        for _ in range(3):
            self.assertEqual(self.submit(url,p).status_code,201)
        self.assertEqual(self.submit(url,p).status_code,429)
        self.assertEqual(Submission.objects.count(),3)

    def test_non_python_uses_existing_worker(self):
        c,p,live,url=self.new()
        self.assertEqual(self.post(url,dict(problem_id=p.pk,code='int main(){}',language='cpp')).status_code,201)
        self.assertIsNone(self.worker('claim',{}).json()['job'])
        self.assertEqual(self.complete()['language'],'cpp')

    def test_legacy_creation_unchanged(self):
        r=self.create(auto_judge=False)
        self.assertEqual(r.status_code,201)
        c=Contest.objects.get(pk=r.json()['contest']['id'])
        self.assertFalse(c.auto_judge)
        self.assertEqual(len(rows('contests')[0]['problems']),1)

    def test_teacher_summary_matches_live_results_and_distinct_students(self):
        c, p, live, url = self.new()
        self.assertEqual(self.submit(url, p).status_code, 201)
        self.complete('Wrong Answer')
        self.assertEqual(self.submit(url, p).status_code, 201)
        self.complete()
        self.assertEqual(self.submit(url, p).status_code, 201)
        self.complete()
        self.assertEqual(self.submit(url, p, 'other').status_code, 201)
        board = self.client.get(live, **self.auth('student')).json()
        self.assertEqual(board['viewer_id'], self.student.pk)
        self.assertTrue(board['viewer_is_student'])
        own = next(r for r in board['standings'] if r['user_id'] == self.student.pk)
        task = own['tasks'][str(p.pk)]
        card = self.client.get('/api/teacher/workspace/', **self.auth('teacher')).json()['contests'][0]
        self.assertEqual((card['participant_count'], card['pending']), (2, 1))
        item = card['problems'][0]
        self.assertEqual((item['accepted_count'], item['attempted_count'], item['pending_count']), (1, 2, 1))
        self.assertEqual(item['results'], [dict(participant='student', score=task['score'], penalty=task['penalty'])])
        self.assertEqual(task['penalty'], own['penalty'])
        self.assertNotIn('private-input', str(card))
        self.assertNotIn('private-expected', str(card))
        self.complete()
        refreshed = self.client.get('/api/teacher/workspace/', **self.auth('teacher')).json()['contests'][0]
        self.assertEqual(refreshed['problems'][0]['accepted_count'], 2)
        self.assertEqual(refreshed['pending'], 0)

    def test_viewer_identity_is_server_scoped(self):
        c, p, live, url = self.new()
        anonymous = self.client.get(live + '?viewer_id=' + str(self.student.pk)).json()
        self.assertIsNone(anonymous['viewer_id'])
        self.assertFalse(anonymous['viewer_is_student'])
        owner = self.client.get(live, **self.auth('teacher')).json()
        self.assertEqual(owner['viewer_id'], self.teacher.pk)
        self.assertFalse(owner['viewer_is_student'])
        self.assertFalse(owner['can_submit'])

    def test_teacher_summary_scheduled_and_legacy(self):
        c, p, live, url = self.new(60)
        card = self.client.get('/api/teacher/workspace/', **self.auth('teacher')).json()['contests'][0]
        self.assertEqual(card['problems'][0]['accepted_count'], 0)
        self.assertEqual(card['participant_count'], 0)
        self.assertEqual(self.client.get(live).json()['problems'], [])
        r = self.create(auto_judge=False)
        manual = r.json()['contest']
        self.assertFalse(manual['auto_judge'])
        self.assertNotIn('accepted_count', manual['problems'][0])
