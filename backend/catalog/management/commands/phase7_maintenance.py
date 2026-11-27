from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from catalog.models import AccessToken, AuthThrottle

class Command(BaseCommand):
    help = 'Dry-run by default; --apply removes only expired API sessions and old throttle counters.'
    def add_arguments(self, parser):
        parser.add_argument('--apply', action='store_true')
    def handle(self, *args, **opts):
        now = timezone.now()
        tokens = AccessToken.objects.filter(created_at__lte=now-timedelta(days=7))
        throttles = AuthThrottle.objects.filter(started_at__lt=now-timedelta(days=2))
        if opts['apply']:
            # Django's delete WHERE is scoped to the expiry predicate; no user or submission deletes.
            self.stdout.write(f'Expired tokens removed: {tokens.delete()[0]}; old counters removed: {throttles.delete()[0]}')
        else:
            self.stdout.write(f'Dry run: expired tokens={tokens.count()}, old counters={throttles.count()}. Use --apply to remove.')
