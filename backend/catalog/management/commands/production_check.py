from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import connection
from catalog.production_rules import configuration_issues

class Command(BaseCommand):
    help = 'Check production configuration without displaying credentials or changing data.'
    def add_arguments(self, parser):
        parser.add_argument('--config-only', action='store_true')
    def handle(self, *args, **opts):
        errors, warnings = configuration_issues(
            debug=settings.DEBUG, secret=settings.SECRET_KEY,
            engine=settings.DATABASES['default']['ENGINE'], hosts=settings.ALLOWED_HOSTS,
            judge_engine=settings.JUDGE_ENGINE, worker_token=settings.JUDGE_WORKER_TOKEN,
            secure_cookies=settings.SESSION_COOKIE_SECURE and settings.CSRF_COOKIE_SECURE,
            secure_proxy=bool(settings.SECURE_PROXY_SSL_HEADER), lease=settings.CMS_LEASE_SECONDS,
            gmail_url=settings.GMAIL_SCRIPT_URL, gmail_secret=settings.GMAIL_SCRIPT_SECRET,
            email_backend=settings.EMAIL_BACKEND, ssl_redirect=settings.SECURE_SSL_REDIRECT, judge0_url=settings.JUDGE0_URL)
        for warning in warnings:
            self.stdout.write(self.style.WARNING(warning))
        if errors:
            for error in errors:
                self.stderr.write(error)
            raise CommandError('Unsafe production configuration; no data changed.')
        if not opts['config_only']:
            try:
                with connection.cursor() as cursor:
                    cursor.execute('SELECT 1')
                    cursor.fetchone()
            except Exception:
                raise CommandError('Database connection check failed.') from None
        self.stdout.write(self.style.SUCCESS('Production configuration check passed.'))
