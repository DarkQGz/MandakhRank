"""Only Judge0 executes code. No submitted program runs in the Django process."""
import base64,json,time,urllib.request
from django.conf import settings
from .models import Submission
from django.utils import timezone

def call(path,data=None):
    headers={'Content-Type':'application/json'}
    if settings.JUDGE0_RAPIDAPI_KEY:
        headers['X-RapidAPI-Key']=settings.JUDGE0_RAPIDAPI_KEY
        headers['X-RapidAPI-Host']=settings.JUDGE0_RAPIDAPI_HOST
    if settings.JUDGE0_TOKEN:headers['X-Auth-Token']=settings.JUDGE0_TOKEN
    request=urllib.request.Request(settings.JUDGE0_URL.rstrip('/')+path,data=json.dumps(data).encode() if data is not None else None,headers=headers)
    with urllib.request.urlopen(request,timeout=15) as r:return json.load(r)

def encode(s):return base64.b64encode(s.encode()).decode()
def evaluate(s):
    passed=0
    try:
        for test in s.test_snapshot:
            if not Submission.objects.filter(pk=s.pk,status='Running').update(updated_at=timezone.now()):return
            token=call('/submissions?base64_encoded=true&wait=false',dict(source_code=encode(s.code),language_id=settings.JUDGE0_PYTHON_ID,stdin=encode(test['stdin']),expected_output=encode(test['expected']),cpu_time_limit=2,wall_time_limit=5,memory_limit=128000,max_file_size=1024,enable_network=False))['token']
            deadline=time.monotonic()+90
            while True:
                result=call('/submissions/'+token+'?fields=status')
                verdict=result['status']['id']
                if verdict>2:break
                if time.monotonic()>=deadline:raise TimeoutError('Judge timeout')
                time.sleep(1)
            if verdict!=3:
                status={4:'Wrong Answer',5:'Time Limit Exceeded',6:'Compilation Error',7:'Runtime Error',8:'Runtime Error',9:'Runtime Error',10:'Runtime Error',11:'Runtime Error',12:'Runtime Error'}.get(verdict,'Judge Error')
                break
            passed+=1
        else:status='Accepted' if s.test_snapshot else 'Judge Error'
    except Exception:
        # Do not expose hidden stdin/output or provider credentials in user responses.
        status='Judge Error'
    Submission.objects.filter(pk=s.pk,status='Running').update(status=status,passed=passed,updated_at=timezone.now())
