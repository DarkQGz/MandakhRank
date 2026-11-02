from datetime import timedelta
from django.contrib.auth import get_user_model
from django.test import TestCase, override_settings
from django.utils import timezone
from .models import Problem, Submission

@override_settings(JUDGE_ENGINE='cms_pull', JUDGE_WORKER_TOKEN='test-secret', CMS_LEASE_SECONDS=60)
class CmsBridgeTests(TestCase):
    def setUp(self):
        self.user = get_user_model().objects.create_user(username='bridge-test-user',password='example-password')
        self.problem = Problem.objects.create(title='Example Add', description='Add',sample_input='1 2', sample_output='3',cms_task_name='addition',published=True)
        self.job = Submission.objects.create(user=self.user,problem=self.problem,code='print(3)',status='Queued',total=1,test_snapshot=[{'stdin':'1 2','expected':'3'}])
        self.auth = {'HTTP_AUTHORIZATION':'Bearer test-secret'}

    def send(self, action, data, auth=True):
        import json
        return self.client.post(f'/api/judge/{action}/',data=json.dumps(data),content_type='application/json', **(self.auth if auth else {}))

    def test_unauthenticated_cannot_claim(self):
        response = self.send('claim',{},auth=False)
        self.assertEqual(response.status_code,401)
        self.job.refresh_from_db()
        self.assertEqual(self.job.status,'Queued')

    def test_claim_complete_once(self):
        result = self.send('claim',{}).json()['job']
        self.assertEqual(result['code'],'print(3)')
        self.assertEqual(result['task_name'],'addition')
        self.assertIsNone(self.send('claim',{}).json()['job'])
        self.assertEqual(self.send('heartbeat',{'id':result['id'],'claim_key':result['claim_key'],'cms_submission_id':'ref1'}).status_code,200)
        report={'id':result['id'],'claim_key':result['claim_key'],'status':'Accepted','passed':1,'total':1}
        self.assertEqual(self.send('complete',report).status_code,200)
        self.assertEqual(self.send('complete',report).status_code,409)
        self.job.refresh_from_db()
        self.assertEqual((self.job.status,self.job.passed,self.job.total,self.job.cms_submission_id),('Accepted',1,1,'ref1'))

    def test_no_invalid_acceptance(self):
        result=self.send('claim',{}).json()['job']
        report={'id':result['id'],'claim_key':result['claim_key'],'status':'Accepted','passed':0,'total':1}
        self.assertEqual(self.send('complete',report).status_code,400)
        self.job.refresh_from_db()
        self.assertEqual(self.job.status,'Running')

    def test_reclaims_stale_and_keeps_cms_id(self):
        result=self.send('claim',{}).json()['job']
        self.send('heartbeat',{'id':result['id'],'claim_key':result['claim_key'],'cms_submission_id':'saved-cms-id'})
        Submission.objects.filter(pk=self.job.pk).update(updated_at=timezone.now()-timedelta(minutes=20))
        again=self.send('claim',{}).json()['job']
        self.assertEqual(again['cms_submission_id'],'saved-cms-id')
        self.assertNotEqual(again['claim_key'],result['claim_key'])
        self.assertEqual(self.send('heartbeat',{'id':result['id'],'claim_key':result['claim_key']}).status_code,409)
