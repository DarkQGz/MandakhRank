from django.test import TestCase,override_settings
from django.core import mail
from .models import EmailVerification
@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class VerificationTests(TestCase):
 def test_verification_flow(self):
  data={'username':'newstudent','email':'student@example.com','password':'strong-Test-pass-8492'}
  self.assertEqual(self.client.post('/api/auth/register/',data=data,content_type='application/json').status_code,201)
  self.assertEqual(self.client.post('/api/auth/login/',data=data,content_type='application/json').status_code,401)
  token=mail.outbox[0].body.split('\n\n')[1]
  self.assertNotEqual(EmailVerification.objects.get().token_hash,token)
  self.assertEqual(self.client.post('/api/auth/verify/',data={'token':token},content_type='application/json').status_code,200)
  self.assertEqual(self.client.post('/api/auth/verify/',data={'token':token},content_type='application/json').status_code,400)
  self.assertEqual(self.client.post('/api/auth/login/',data=data,content_type='application/json').status_code,200)
 def test_delivery_failure_rolls_back(self):
  from unittest.mock import patch
  from django.contrib.auth import get_user_model
  with patch('catalog.accounts.send_mail',side_effect=OSError()):
   r=self.client.post('/api/auth/register/',data={'username':'newstudent','email':'s@example.com','password':'strong-Test-pass-8492'},content_type='application/json')
  self.assertEqual(r.status_code,503)
  self.assertFalse(get_user_model().objects.filter(username='newstudent').exists())
