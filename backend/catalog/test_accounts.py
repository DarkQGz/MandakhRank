from datetime import timedelta
from unittest.mock import patch
from django.test import TestCase, override_settings
from django.core import mail
from django.contrib.auth import get_user_model
from django.utils import timezone
from .models import EmailVerification, AccessToken

@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class VerificationTests(TestCase):
    data = {'username':'newstudent','email':'student@example.com','password':'strong-Test-pass-8492'}
    def post(self, action, data):
        return self.client.post('/api/auth/'+action+'/',data=data,content_type='application/json')
    def register(self):
        self.assertEqual(self.post('register',self.data).status_code,201)
        return mail.outbox[-1].body.split('\n\n')[1]
    def verify(self, code, **extra):
        return self.post('verify',{'email':self.data['email'],'code':code,**extra})
    def test_verification_auto_login_and_replay(self):
        code=self.register()
        self.assertRegex(code,r'^[0-9]{4}$')
        self.assertNotEqual(EmailVerification.objects.get().token_hash,code)
        self.assertEqual(self.post('login',self.data).status_code,401)
        r=self.verify(code)
        self.assertEqual(r.status_code,200)
        self.assertTrue(AccessToken.objects.filter(key=r.json()['token']).exists())
        self.assertEqual(self.client.get('/api/submissions/',HTTP_AUTHORIZATION='Bearer '+r.json()['token']).status_code,200)
        self.assertEqual(self.verify(code).status_code,400)
        self.assertEqual(self.post('login',self.data).status_code,200)
    @patch('catalog.accounts.secrets.randbelow', return_value=7)
    def test_leading_zero_and_wrong_email(self, random):
        code=self.register()
        self.assertEqual(code,'0007')
        self.assertEqual(self.verify(code,email='other@example.com').status_code,400)
        self.assertEqual(self.verify(code).status_code,200)
    def test_five_guesses_lock_code(self):
        code=self.register()
        wrong='0000' if code!='0000' else '0001'
        for _ in range(5): self.assertEqual(self.verify(wrong).status_code,400)
        self.assertEqual(self.verify(code).status_code,429)
        self.assertFalse(get_user_model().objects.get().is_active)
    def test_expiry(self):
        code=self.register()
        EmailVerification.objects.update(created_at=timezone.now()-timedelta(minutes=11))
        self.assertEqual(self.verify(code).status_code,400)
    def test_resend_cooldown_password_and_invalidation(self):
        with patch('catalog.accounts.secrets.randbelow',side_effect=[1234,5678]):
            old=self.register()
            self.assertEqual(self.post('resend',self.data).status_code,429)
            EmailVerification.objects.update(created_at=timezone.now()-timedelta(minutes=2))
            self.assertEqual(self.post('resend',{**self.data,'password':'wrong'}).status_code,400)
            self.assertEqual(self.post('resend',self.data).status_code,200)
        self.assertEqual(self.verify(old).status_code,400)
        self.assertEqual(self.verify('5678').status_code,200)
    def test_resend_failure_preserves_code(self):
        self.register()
        EmailVerification.objects.update(created_at=timezone.now()-timedelta(minutes=2))
        before=EmailVerification.objects.get().token_hash
        with patch('catalog.accounts.send_mail',side_effect=OSError()):
            self.assertEqual(self.post('resend',self.data).status_code,503)
        self.assertEqual(EmailVerification.objects.get().token_hash,before)
    def test_delivery_failure_rolls_back(self):
        with patch('catalog.accounts.send_mail',side_effect=OSError()):
            self.assertEqual(self.post('register',self.data).status_code,503)
        self.assertFalse(get_user_model().objects.exists())
    def test_duplicate_email_case_insensitive(self):
        self.register()
        self.assertEqual(self.post('register',{**self.data,'username':'another','email':'STUDENT@example.com'}).status_code,400)
    def test_invalid_body_and_numeric_code(self):
        self.assertEqual(self.post('verify',{'email':[], 'code':'1234'}).status_code,400)
        self.assertEqual(self.verify(1234).status_code,400)
    def test_login_throttled(self):
        for _ in range(20): self.post('login',self.data)
        self.assertEqual(self.post('login',self.data).status_code,429)
