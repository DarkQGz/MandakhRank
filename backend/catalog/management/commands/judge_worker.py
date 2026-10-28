import time
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.conf import settings
from django.db import close_old_connections
from django.utils import timezone
from catalog.models import Submission, AuthThrottle, AccessToken
from catalog.judge import evaluate

class Command(BaseCommand):
    help = 'Consume queued submissions automatically. Supports multiple PostgreSQL workers.'
    def add_arguments(self, parser):
        parser.add_argument('--once', action='store_true')
        parser.add_argument('--recover', action='store_true', help='Recover stale work only.')
    def handle(self, *args, **opts):
        self.stdout.write('Judge worker ready.' if settings.JUDGE0_URL else 'Judge disabled: configure JUDGE0_URL and restart.')
        try:
            while True:
                close_old_connections()
                # evaluate() heartbeats between tests; crashed work becomes retryable.
                Submission.objects.filter(status='Running', updated_at__lt=timezone.now()-timedelta(minutes=5)).update(status='Judge Error', updated_at=timezone.now())
                AccessToken.objects.filter(created_at__lt=timezone.now()-timedelta(days=7)).delete()
                AuthThrottle.objects.filter(started_at__lt=timezone.now()-timedelta(days=2)).delete()
                s = Submission.objects.filter(status='Queued').order_by('id').first() if settings.JUDGE0_URL else None
                if s and Submission.objects.filter(pk=s.pk, status='Queued').update(status='Running', updated_at=timezone.now()):
                    evaluate(s)
                if opts['once']: break
                if not s: time.sleep(2)
        except KeyboardInterrupt:
            self.stdout.write('Worker stopped.')
