import json,secrets
from datetime import timedelta
from django.conf import settings
from django.contrib.auth import authenticate,get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.db import transaction,IntegrityError
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from .models import Problem,Submission,AccessToken

def response(data,status=200):
    result=JsonResponse(data,status=status,json_dumps_params={'ensure_ascii':False})
    result['Cache-Control']='no-store'
    return result
def current_user(request):
    header=request.headers.get('Authorization','')
    if not header.startswith('Bearer '):return None
    token=AccessToken.objects.select_related('user').filter(key=header[7:],created_at__gt=timezone.now()-timedelta(days=7),user__is_active=True).first()
    return token.user if token else None

def payload(request):
    try:
        data=json.loads(request.body)
        if not isinstance(data,dict):raise ValueError()
        return data
    except (ValueError,UnicodeDecodeError):return None

@csrf_exempt
@require_http_methods(['POST'])
def account(request,action):
    data=payload(request)
    if data is None:return response({'error':'JSON өгөгдөл буруу.'},400)
    if action=='logout':
        AccessToken.objects.filter(key=request.headers.get('Authorization','').removeprefix('Bearer ')).delete()
        return response({'ok':True})
    name=data.get('username','');password=data.get('password','')
    if not isinstance(name,str) or not isinstance(password,str) or not 3<=len(name)<=40 or len(password)>200:return response({'error':'Нэр 3–40 тэмдэгт байна.'},400)
    User=get_user_model()
    if action=='register':
        candidate=User(username=name)
        try:
            candidate.full_clean(exclude=['password','last_login','date_joined'])
            validate_password(password,candidate)
            with transaction.atomic():user=User.objects.create_user(username=name,password=password)
        except (ValidationError,IntegrityError):return response({'error':'Нэр ашиглагдсан эсвэл нууц үг шаардлага хангахгүй. 8+ тэмдэгттэй, таахад хэцүү нууц үг сонгоно уу.'},400)
    elif action=='login':
        user=authenticate(username=name,password=password)
        if not user:return response({'error':'Нэр эсвэл нууц үг буруу.'},401)
    else:return response({'error':'Not found'},404)
    token=secrets.token_hex(32)
    AccessToken.objects.create(key=token,user=user)
    return response({'token':token,'username':user.username})

def problem_data(p,solved):
    return dict(id=p.id,title=p.title,description=p.description,difficulty=p.difficulty,topic=p.topic,points=p.points,input=p.sample_input,output=p.sample_output,completed=p.id in solved)

@require_http_methods(['GET'])
def problems(request):
    user=current_user(request)
    solved=set(Submission.objects.filter(user=user,status='Accepted').values_list('problem_id',flat=True)) if user else set()
    return response({'results':[problem_data(p,solved) for p in Problem.objects.filter(published=True)],'demo':False})

@csrf_exempt
@require_http_methods(['GET','POST'])
def submissions(request):
    user=current_user(request)
    if not user:return response({'error':'Эхлээд нэвтэрнэ үү.'},401)
    if request.method=='GET':
        rows=Submission.objects.filter(user=user).select_related('problem')[:100]
        return response({'results':[dict(id=s.id,problem_id=s.problem_id,title=s.problem.title,status=s.status,passed=s.passed,total=s.total,created_at=s.created_at.isoformat()) for s in rows]})
    if not settings.JUDGE0_URL:return response({'error':'Judge0 тохируулагдаагүй байна.'},503)
    data=payload(request)
    if data is None:return response({'error':'JSON өгөгдөл буруу.'},400)
    code=data.get('code','');pid=data.get('problem_id')
    if not isinstance(code,str) or not code.strip() or len(code.encode())>20000:return response({'error':'Код хоосон эсвэл 20KB-аас их байна.'},400)
    if not isinstance(pid,int):return response({'error':'Бодлогын дугаар буруу.'},400)
    p=Problem.objects.filter(pk=pid,published=True).first()
    if not p:return response({'error':'Бодлого олдсонгүй.'},404)
    tests=list(p.tests.values('stdin','expected'))
    if not tests:return response({'error':'Бодлогын тестүүд бэлэн болоогүй.'},409)
    # Serialize per-user queue admission to prevent parallel request bypass.
    with transaction.atomic():
        get_user_model().objects.select_for_update().get(pk=user.pk)
        if Submission.objects.filter(user=user,status__in=['Queued','Running']).count()>=3:
            return response({'error':'Өмнөх илгээлтээ шалгуулж дуустал хүлээнэ үү.'},429)
        if Submission.objects.filter(user=user,created_at__gt=timezone.now()-timedelta(hours=1)).count()>=30:
            return response({'error':'Нэг цагт 30 удаа илгээх боломжтой. Түр хүлээнэ үү.'},429)
        s=Submission.objects.create(user=user,problem=p,code=code,test_snapshot=tests,total=len(tests))
    return response({'id':s.id,'status':s.status},201)
