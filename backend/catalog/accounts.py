"""Email verification with short-lived, single-use four-digit codes."""
import re
import secrets
from datetime import timedelta
from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.validators import validate_email
from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.db import transaction, IntegrityError
from django.utils import timezone
from django.utils.crypto import salted_hmac, constant_time_compare
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from .models import EmailVerification, AccessToken, AuthThrottle
from .practice import payload, response, account as old_account


def limited(scope, identity, maximum, seconds):
    # Database-backed limits work across web processes; never store raw IPs/emails.
    key = salted_hmac('auth-limit', scope + ':' + identity, algorithm='sha256').hexdigest()
    with transaction.atomic():
        AuthThrottle.objects.get_or_create(key=key)
        row = AuthThrottle.objects.select_for_update().get(key=key)
        now = timezone.now()
        if row.started_at <= now - timedelta(seconds=seconds):
            row.started_at = now
            row.count = 0
        row.count += 1
        row.save()
        return row.count > maximum


def digest(row, code):
    return salted_hmac('verification-code', f'{row.user_id}:{row.created_at.isoformat()}:{code}', algorithm='sha256').hexdigest()


def issue(row):
    code = f'{secrets.randbelow(10000):04d}'
    row.created_at = timezone.now()
    row.attempts = 0
    row.token_hash = digest(row, code)
    row.save()
    send_mail('MandakhRank — Баталгаажуулах код',
              f'Таны баталгаажуулах код:\n\n{code}\n\n10 минутын дотор апп дээр оруулна уу. Кодыг бусдад бүү дамжуулаарай.',
              settings.DEFAULT_FROM_EMAIL, [row.email], fail_silently=False)


def signed_in(user):
    key = secrets.token_hex(32)
    AccessToken.objects.create(user=user, key=key)
    return response({'token': key, 'username': user.username, 'verified': True})


@csrf_exempt
@require_POST
def account(request, action):
    data = payload(request)
    if data is None:
        return response({'error': 'JSON буруу.'}, 400)
    email = data.get('email', '')
    name = data.get('username', '')
    password = data.get('password', '')
    if not all(isinstance(v, str) for v in (email, name, password)):
        return response({'error': 'Оруулсан мэдээлэл буруу.'}, 400)
    email = email.strip().lower()
    name = name.strip()
    if len(email) > 254 or len(name) > 150 or len(password) > 200:
        return response({'error': 'Оруулсан мэдээлэл хэт урт байна.'}, 400)
    if action == 'logout':
        return old_account(request, action)
    if action not in ('register', 'verify', 'resend', 'login'):
        return response({'error': 'Not found'}, 404)
    # REMOTE_ADDR is server-provided; do not trust a client-supplied Forwarded header.
    if limited('ip', request.META.get('REMOTE_ADDR', ''), 200, 3600):
        return response({'error': 'Хэт олон хүсэлт. Дараа дахин оролдоно уу.'}, 429)
    identity = name.lower() if action == 'login' else email
    if limited(action, identity, 20 if action in ('verify', 'login') else 5, 900 if action in ('verify', 'login') else 3600):
        return response({'error': 'Хэт олон оролдлого. Түр хүлээнэ үү.'}, 429)
    if action == 'login':
        return old_account(request, action)
    if action == 'verify':
        code = data.get('code', '')
        if not isinstance(code, str) or not re.fullmatch(r'[0-9]{4}', code):
            return response({'error': '4 оронтой код оруулна уу.'}, 400)
        with transaction.atomic():
            row = EmailVerification.objects.select_for_update().select_related('user').filter(email=email, verified=False).first()
            if not row or row.created_at <= timezone.now() - timedelta(minutes=10):
                return response({'error': 'Кодын хугацаа дууссан эсвэл код буруу. Шинэ код авна уу.'}, 400)
            if row.attempts >= 5:
                return response({'error': '5 удаа буруу оруулсан. Шинэ код авна уу.'}, 429)
            row.attempts += 1
            row.save(update_fields=['attempts'])
            if not constant_time_compare(row.token_hash, digest(row, code)):
                return response({'error': 'Код буруу байна.'}, 400)
            row.verified = True
            row.token_hash = ''
            row.save(update_fields=['verified', 'token_hash'])
            user = row.user
            user.is_active = True
            user.save(update_fields=['is_active'])
            return signed_in(user)
    if action == 'resend':
        try:
            with transaction.atomic():
                row = EmailVerification.objects.select_for_update().select_related('user').filter(email=email, verified=False).first()
                # Require the registration password so strangers cannot reset attempts.
                if not row or not row.user.check_password(password):
                    return response({'error': 'Имэйл эсвэл нууц үг буруу.'}, 400)
                if row.created_at > timezone.now() - timedelta(seconds=60):
                    return response({'error': 'Шинэ код авахын өмнө 60 секунд хүлээнэ үү.'}, 429)
                issue(row)
        except Exception:
            return response({'error': 'Имэйл илгээж чадсангүй. Дараа дахин оролдоно уу.'}, 503)
        return response({'verification_required': True, 'email': email, 'expires_in': 600})
    if not 3 <= len(name) <= 40:
        return response({'error': 'Username 3–40 тэмдэгт байна.'}, 400)
    User = get_user_model()
    candidate = User(username=name, email=email, is_active=False)
    try:
        validate_email(email)
        validate_password(password, candidate)
        candidate.full_clean(exclude=['password', 'last_login', 'date_joined'])
        if User.objects.filter(email__iexact=email).exists():
            return response({'error': 'Имэйл бүртгэлтэй байна. Нэвтрэх эсвэл шинэ код авах хэсгийг ашиглана уу.'}, 400)
    except ValidationError:
        return response({'error': 'Нэр/имэйл буруу эсвэл нууц үг сул байна.'}, 400)
    try:
        with transaction.atomic():
            user = User.objects.create_user(username=name, email=email, password=password, is_active=False)
            row = EmailVerification.objects.create(user=user, email=email)
            issue(row)
    except IntegrityError:
        return response({'error': 'Нэр эсвэл имэйл бүртгэлтэй байна.'}, 400)
    except Exception:
        return response({'error': 'Баталгаажуулах имэйл илгээж чадсангүй. Дараа дахин оролдоно уу.'}, 503)
    return response({'verification_required': True, 'email': email, 'expires_in': 600}, 201)
