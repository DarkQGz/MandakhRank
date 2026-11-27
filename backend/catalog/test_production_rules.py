from unittest import TestCase
from .production_rules import configuration_issues

class ProductionRulesTests(TestCase):
    def good(self, **changes):
        args=dict(debug=False,secret='strong-persistent-example-1234567890',engine='django.db.backends.postgresql',hosts=['example.org'],judge_engine='docker_pull',worker_token='random-example-token-1234567890-abcd',secure_cookies=True,secure_proxy=True,lease=600,ssl_redirect=True)
        args.update(changes)
        return configuration_issues(**args)
    def test_good(self): self.assertEqual(self.good(),([],[]))
    def test_unsafe_defaults_rejected(self):
        for changes in [dict(debug=True),dict(secret='local-template-only-not-for-production'),dict(engine='django.db.backends.sqlite3'),dict(hosts=['*']),dict(hosts=['localhost']),dict(secure_cookies=False),dict(secure_proxy=False),dict(worker_token=''),dict(lease=30),dict(judge_engine='judge0',judge0_url='')]:
            with self.subTest(changes=changes): self.assertTrue(self.good(**changes)[0])
    def test_warnings_not_secrets(self):
        e,w=self.good(worker_token='short',email_backend='catalog.email_backend.GmailScriptBackend',gmail_url='http://bad')
        self.assertFalse(e);self.assertEqual(len(w),2);self.assertNotIn('http://bad',str(w))
