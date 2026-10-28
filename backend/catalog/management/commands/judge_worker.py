import time
from django.core.management.base import BaseCommand,CommandError
from django.conf import settings
from django.utils import timezone
from catalog.models import Submission
from catalog.judge import evaluate
class Command(BaseCommand):
    help='Judge0 submission worker. Run one instance for local SQLite.'
    def add_arguments(self,parser):
        parser.add_argument('--once',action='store_true')
        parser.add_argument('--recover',action='store_true',help='Mark interrupted Running submissions Judge Error; only when no other worker is running.')
    def handle(self,*args,**opts):
        if not settings.JUDGE0_URL:raise CommandError('Set JUDGE0_URL first.')
        if opts['recover']:Submission.objects.filter(status='Running').update(status='Judge Error')
        self.stdout.write('Judge worker ready. Ctrl+C to stop.')
        try:
            while True:
                s=Submission.objects.filter(status='Queued').order_by('id').first()
                if s and Submission.objects.filter(pk=s.pk,status='Queued').update(status='Running',updated_at=timezone.now()):evaluate(s)
                if opts['once']:break
                if not s:time.sleep(1)
        except KeyboardInterrupt:self.stdout.write('Stopped. Use --recover after an interrupted submission.')
