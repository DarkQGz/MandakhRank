"""Send verification codes through an owner-authorized Google Apps Script.

The Flutter app never receives the shared secret or Gmail credentials.
"""
import json
import re
import urllib.request
from urllib.parse import urlparse
from django.conf import settings
from django.core.mail.backends.base import BaseEmailBackend

class GmailScriptBackend(BaseEmailBackend):
    def send_messages(self, email_messages):
        count = 0
        for message in email_messages:
            try:
                url = settings.GMAIL_SCRIPT_URL
                parsed = urlparse(url)
                secret = settings.GMAIL_SCRIPT_SECRET
                if (parsed.scheme != 'https' or parsed.netloc != 'script.google.com'
                    or not re.fullmatch(r'/macros/s/[A-Za-z0-9_-]+/exec', parsed.path)
                    or parsed.query or parsed.fragment or not re.fullmatch(r'[a-f0-9]{64}', secret)):
                    raise ValueError('Google mailer configuration missing or invalid')
                code = re.search(r'\n\n([0-9]{4})\n\n', message.body)
                if not code or len(message.to) != 1 or message.cc or message.bcc:
                    raise ValueError('Only single-recipient verification codes are supported')
                data = {'secret': secret, 'to': message.to[0], 'code': code.group(1)}
                req = urllib.request.Request(url, data=json.dumps(data).encode(),
                    headers={'Content-Type': 'application/json'}, method='POST')
                with urllib.request.urlopen(req, timeout=30) as result:
                    reply = json.loads(result.read(8192))
                if reply.get('ok') is not True:
                    raise RuntimeError('Google mailer rejected request')
                count += 1
            except Exception:
                if not self.fail_silently:
                    # Do not expose URL tokens, secrets, addresses or codes in errors.
                    raise RuntimeError('Verification email delivery failed') from None
        return count
