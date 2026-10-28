import hashlib,secrets
from datetime import timedelta
from django.conf import settings
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.validators import validate_email
from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.db import transaction,IntegrityError
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST
from .models import EmailVerification
from .practice import payload,response,account as old_account

@csrf_exempt
@require_POST
def account(request,action):
    data=payload(request)
    if data is None:return response({'error':'JSON буруу.'},400)
    if action=='verify':
        token=data.get('token','')
        if not isinstance(token,str) or len(token)!=64:return response({'error':'Баталгаажуулах код буруу.'},400)
        with transaction.atomic():
            row=EmailVerification.objects.select_for_update().filter(token_hash=hashlib.sha256(token.encode()).hexdigest(),verified=False,created_at__gt=timezone.now()-timedelta(hours=24)).first()
            if not row:return response({'error':'Код буруу, ашиглагдсан эсвэл хугацаа дууссан.'},400)
            row.verified=True;row.token_hash='';row.save()
            user=row.user;user.is_active=True;user.save(update_fields=['is_active'])
        return response({'ok':True})
    if action!='register':return old_account(request,action)
    name=data.get('username','');password=data.get('password','');email=data.get('email','')
    if not all(isinstance(v,str) for v in (name,password,email)) or not 3<=len(name)<=40 or len(password)>200:return response({'error':'Нэр эсвэл нууц үг буруу.'},400)
    email=email.strip().lower()
    User=get_user_model();candidate=User(username=name,email=email,is_active=False)
    try:
        validate_email(email);validate_password(password,candidate)
        candidate.full_clean(exclude=['password','last_login','date_joined'])
    except ValidationError:return response({'error':'Нэр/имэйл буруу эсвэл нууц үг сул байна.'},400)
    token=secrets.token_hex(32)
    try:
        with transaction.atomic():
            user=User.objects.create_user(username=name,email=email,password=password,is_active=False)
            EmailVerification.objects.create(user=user,email=email,token_hash=hashlib.sha256(token.encode()).hexdigest())
            send_mail('Mandakhrank — Имэйл баталгаажуулах',f'Бүртгэлээ баталгаажуулахын тулд аппын кодын талбарт дараах кодыг оруулна уу:\n\n{token}\n\n24 цагийн дотор хүчинтэй. Хэрэв та бүртгүүлээгүй бол энэ имэйлийг үл хэрэгсэнэ үү.',settings.DEFAULT_FROM_EMAIL,[email],fail_silently=False)
    except IntegrityError:return response({'error':'Нэр эсвэл имэйл бүртгэлтэй байна.'},400)
    except Exception:return response({'error':'Баталгаажуулах имэйл илгээж чадсангүй. Дараа дахин оролдоно уу.'},503)
    return response({'verification_required':True},201)
