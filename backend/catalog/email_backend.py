import json,urllib.request
from django.conf import settings
from django.core.mail.backends.base import BaseEmailBackend
class ResendBackend(BaseEmailBackend):
    def send_messages(self,email_messages):
        count=0
        for message in email_messages:
            request=urllib.request.Request('https://api.resend.com/emails',data=json.dumps({'from':message.from_email,'to':message.to,'subject':message.subject,'text':message.body}).encode(),headers={'Authorization':'Bearer '+settings.RESEND_API_KEY,'Content-Type':'application/json'},method='POST')
            with urllib.request.urlopen(request,timeout=15) as r:
                if r.status not in (200,201):raise RuntimeError('Email delivery failed')
            count+=1
        return count
