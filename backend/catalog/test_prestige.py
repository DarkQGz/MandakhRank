import json
from django.contrib.auth import get_user_model
from django.test import TestCase
from .models import AccessToken, ClassroomTeacher, Problem, Submission, ProfileAppearance
from .prestige_rules import DEFAULT
from .profile import profile_data
from .views import rows


class PrestigeTests(TestCase):
    def setUp(self):
        U=get_user_model()
        self.a=U.objects.create_user(username='alpha')
        self.b=U.objects.create_user(username='beta')
        self.staff=U.objects.create_user(username='staff',is_staff=True)
        self.teacher=U.objects.create_user(username='teacher')
        ClassroomTeacher.objects.create(user=self.teacher)
        AccessToken.objects.create(user=self.a,key='a'*64)
        AccessToken.objects.create(user=self.b,key='b'*64)
        self.problem=Problem.objects.create(title='P',published=True,points=20)
        self.url='/api/profile/appearance/'
        self.headers={'HTTP_AUTHORIZATION':'Bearer '+'a'*64}
    def submit(self,user):
        return Submission.objects.create(user=user,problem=self.problem,status='Accepted',code='print(1)')
    def save(self,data,headers=None):
        return self.client.post(self.url,json.dumps(data),content_type='application/json',**(self.headers if headers is None else headers))
    def test_authentication_and_unearned_cosmetic(self):
        self.assertEqual(self.client.get(self.url).status_code,401)
        self.assertEqual(self.save(DEFAULT,{}).status_code,401)
        self.assertEqual(self.save(dict(DEFAULT,frame='solve_1')).status_code,400)
        self.assertEqual(self.save(dict(DEFAULT,user_id=self.b.pk)).status_code,400)
        self.assertEqual(ProfileAppearance.objects.count(),0)
    def test_save_public_and_no_duplicate_or_xp_change(self):
        self.submit(self.a)
        before=profile_data(self.a,is_owner=True)['progression']
        data=dict(DEFAULT,frame='solve_1',accent='solve_1',title='solve_1',featured=['solve_1'],background='gradient',motion=False)
        for _ in range(2):
            r=self.save(data);self.assertEqual(r.status_code,200,r.content)
        self.assertEqual(ProfileAppearance.objects.count(),1)
        own=self.client.get('/api/profile/me/',**self.headers).json()
        other=self.client.get(f'/api/profile/public/{self.a.pk}/',HTTP_AUTHORIZATION='Bearer '+'b'*64).json()
        self.assertEqual(own['appearance']['preferences'],data)
        self.assertNotIn('preferences',other['appearance']);self.assertNotIn('rewards',other['appearance'])
        self.assertEqual(other['appearance']['frame']['id'],'solve_1')
        self.assertEqual(own['progression'],before)
        self.assertEqual(other['appearance']['rank'],1)
        self.assertFalse(ProfileAppearance.objects.filter(user=self.b).exists())
    def test_reset_progress_disables_equipped_reward(self):
        attempt=self.submit(self.a)
        self.assertEqual(self.save(dict(DEFAULT,frame='solve_1',featured=['solve_1'])).status_code,200)
        attempt.delete()
        data=profile_data(self.a,is_owner=True)['appearance']
        self.assertIsNone(data['frame']);self.assertEqual(data['featured'],[]);self.assertIsNone(data['rank'])
        self.assertEqual(data['preferences']['frame'],'')
    def test_rank_ties_role_and_zero_points(self):
        self.submit(self.a);self.submit(self.teacher);self.submit(self.staff)
        result={r['id']:r for r in rows('rankings')}
        self.assertEqual(result[self.a.pk]['prestige_rank'],1)
        self.assertEqual(result[self.teacher.pk]['prestige_rank'],1)
        self.assertEqual(result[self.teacher.pk]['role'],'teacher')
        self.assertEqual(result[self.b.pk]['rank'],3)
        self.assertIsNone(result[self.b.pk]['prestige_rank'])
        self.assertNotIn(self.staff.pk,result)
        self.assertIsNone(profile_data(self.staff)['appearance']['rank'])
        self.assertEqual(profile_data(self.teacher)['appearance']['rank'],1)
    def test_rank_changes_without_customization_write(self):
        self.submit(self.a)
        self.assertEqual(profile_data(self.a)['appearance']['rank'],1)
        for i in range(5):
            u=get_user_model().objects.create_user(username='more'+str(i))
            p=Problem.objects.create(title='Higher'+str(i),published=True,points=50+i)
            Submission.objects.create(user=u,problem=p,status='Accepted',code='pass')
        self.assertIsNone(profile_data(self.a)['appearance']['rank'])
        self.assertEqual(ProfileAppearance.objects.count(),0)
