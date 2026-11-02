"""Send verification codes through an owner-authorized Google Apps Script.

The Flutter app never receives the shared secret or Gmail credentials.
"""
import json
import logging
import re
import urllib.request
from urllib.parse import urlparse
from django.conf import settings
from django.core.mail.backends.base import BaseEmailBackend

logger = logging.getLogger(__name__)


def mailer_configuration_error():
    """Safe diagnostic; never return a URL, secret or recipient to clients."""
    if settings.EMAIL_BACKEND != "catalog.email_backend.GmailScriptBackend":
        return "EMAIL_BACKEND must be catalog.email_backend.GmailScriptBackend"
    url = settings.GMAIL_SCRIPT_URL
    parsed = urlparse(url)
    if (parsed.scheme != "https" or parsed.netloc != "script.google.com"
            or not re.fullmatch(r"/macros/s/[A-Za-z0-9_-]+/exec", parsed.path)
            or parsed.query or parsed.fragment):
        return "GMAIL_SCRIPT_URL must be the deployed Google Apps Script /exec URL"
    if not re.fullmatch(r"[a-f0-9]{64}", settings.GMAIL_SCRIPT_SECRET):
        return "GMAIL_SCRIPT_SECRET must be the same 64-character lowercase hex secret as MAILER_SECRET in Apps Script"
    return None

class GmailScriptBackend(BaseEmailBackend):
    def send_messages(self, email_messages):
        count = 0
        for message in email_messages:
            try:
                if mailer_configuration_error():
                    raise ValueError("Google mailer configuration missing or invalid")
                url = settings.GMAIL_SCRIPT_URL
                secret = settings.GMAIL_SCRIPT_SECRET
                code = re.search(r'\n\n([0-9]{4})\n\n', message.body)
                if not code or len(message.to) != 1 or message.cc or message.bcc:
                    raise ValueError('Only single-recipient verification codes are supported')
                data = {'secret': secret, 'to': message.to[0], 'code': code.group(1)}
                req = urllib.request.Request(url, data=json.dumps(data).encode(),
                    headers={'Content-Type': 'application/json'}, method='POST')
                with urllib.request.urlopen(req, timeout=30) as result:
                    reply = json.loads(result.read(8192))
                if reply.get('ok') is not True:
                    reason = reply.get('reason')
                    # Only accept known fixed identifiers, never log remote text.
                    if reason in ('invalid_request', 'busy', 'rate_limited', 'quota_exceeded', 'delivery_error'):
                        logger.warning('Google Apps Script mailer rejected request: %s', reason)
                    raise RuntimeError('Google mailer rejected request')
                count += 1
            except Exception as error:
                logger.warning("Verification email delivery failed (error type: %s); check Render env and Apps Script Executions", type(error).__name__)
                if not self.fail_silently:
                    # Do not expose URL tokens, secrets, addresses or codes in errors.
                    raise RuntimeError('Verification email delivery failed') from None
        return count
