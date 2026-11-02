"""Validate mail delivery settings; optionally send a real four-digit test code."""
import secrets

from django.conf import settings
from django.core.mail import send_mail
from django.core.management.base import BaseCommand, CommandError
from django.core.validators import validate_email
from django.core.exceptions import ValidationError

from catalog.email_backend import mailer_configuration_error


class Command(BaseCommand):
    help = 'Check Google Apps Script mailer configuration. --to sends a REAL test email.'

    def add_arguments(self, parser):
        parser.add_argument('--to', dest='recipient', default='', help='Email address to receive a test code')

    def handle(self, *args, **options):
        error = mailer_configuration_error()
        if error:
            raise CommandError(error)
        self.stdout.write(self.style.SUCCESS('Mailer environment configuration is valid (delivery not yet tested).'))
        recipient = options['recipient'].strip()
        if not recipient:
            self.stdout.write('To test actual delivery, rerun: python manage.py check_mailer --to YOUR_EMAIL')
            return
        try:
            validate_email(recipient)
        except ValidationError:
            raise CommandError('Invalid recipient email address') from None
        code = f'{secrets.randbelow(10000):04d}'
        try:
            send_mail('MandakhRank — Баталгаажуулах код',
                      f'Тест код:\n\n{code}\n\nЭнэ бол шалгах имэйл.',
                      settings.DEFAULT_FROM_EMAIL, [recipient], fail_silently=False)
        except Exception:
            raise CommandError('Test email failed: check Apps Script deployment, authorization, secret and quota.') from None
        self.stdout.write(self.style.SUCCESS('Google Apps Script accepted the test email. Check the recipient inbox/spam for delivery.'))
        # The code is intentionally not printed into logs.
