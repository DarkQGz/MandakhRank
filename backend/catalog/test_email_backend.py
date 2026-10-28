import json
from unittest.mock import patch, MagicMock
from django.core.mail import EmailMessage
from django.test import SimpleTestCase, override_settings
from .email_backend import GmailScriptBackend

@override_settings(GMAIL_SCRIPT_URL='https://script.google.com/macros/s/test-id/exec',GMAIL_SCRIPT_SECRET='a'*64)
class GmailBackendTests(SimpleTestCase):
    def message(self):return EmailMessage('Verification','Таны код:\n\n0007\n\n10 минут.',to=['test@example.com'])
    def mock_reply(self, mock, payload):
        result=MagicMock();result.read.return_value=json.dumps(payload).encode()
        mock.return_value.__enter__.return_value=result
    @patch('catalog.email_backend.urllib.request.urlopen')
    def test_single_recipient_and_leading_zero(self,mock):
        self.mock_reply(mock,{'ok':True})
        self.assertEqual(GmailScriptBackend().send_messages([self.message()]),1)
        request=mock.call_args.args[0]
        self.assertEqual(json.loads(request.data),{'secret':'a'*64,'to':'test@example.com','code':'0007'})
        self.assertNotIn('secret',request.full_url)
    @patch('catalog.email_backend.urllib.request.urlopen')
    def test_rejected_provider_response_fails(self,mock):
        self.mock_reply(mock,{'ok':False})
        with self.assertRaisesRegex(RuntimeError,'Verification email delivery failed'):
            GmailScriptBackend().send_messages([self.message()])
    @patch('catalog.email_backend.urllib.request.urlopen',side_effect=TimeoutError('sensitive details'))
    def test_network_error_is_redacted(self,mock):
        with self.assertRaises(RuntimeError) as caught:GmailScriptBackend().send_messages([self.message()])
        self.assertNotIn('sensitive',str(caught.exception))
        self.assertEqual(GmailScriptBackend(fail_silently=True).send_messages([self.message()]),0)
    @override_settings(GMAIL_SCRIPT_URL='http://attacker.invalid/exec')
    @patch('catalog.email_backend.urllib.request.urlopen')
    def test_bad_url_never_receives_secret(self,mock):
        with self.assertRaises(RuntimeError):GmailScriptBackend().send_messages([self.message()])
        mock.assert_not_called()
    @override_settings(GMAIL_SCRIPT_SECRET='')
    def test_missing_secret(self):
        with self.assertRaises(RuntimeError):GmailScriptBackend().send_messages([self.message()])
    @patch('catalog.email_backend.urllib.request.urlopen')
    def test_arbitrary_body_or_multiple_recipients_rejected(self,mock):
        msg=self.message();msg.body='arbitrary text'
        with self.assertRaises(RuntimeError):GmailScriptBackend().send_messages([msg])
        msg=self.message();msg.to.append('second@example.com')
        with self.assertRaises(RuntimeError):GmailScriptBackend().send_messages([msg])
        mock.assert_not_called()
