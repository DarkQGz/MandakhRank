"""Prototype compatible with MandakhRank's Judge0 POST/GET submission API.
UNTRUSTED programs run ONLY in isolated Docker containers on a separate Linux VM.
"""
import base64, binascii, json, logging, os, secrets, subprocess, threading, time, uuid
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
TOKEN=os.environ.get('JUDGE_API_TOKEN','')
IMAGE='python:3.12-alpine'
RUNNER=os.path.join(os.path.dirname(os.path.realpath(__file__)),'runner.py')
sem=threading.BoundedSemaphore(12)
executor=ThreadPoolExecutor(max_workers=2)
jobs={}
lock=threading.Lock()
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')

def decode(value):
    try: return base64.b64decode(value,validate=True).decode('utf-8')
    except (binascii.Error,ValueError,UnicodeDecodeError,TypeError) as e: raise ValueError('invalid base64 input') from e

def execute(token,code,stdin,expected):
    name='mr-'+uuid.uuid4().hex
    cmd=['docker','run','--rm','-i','--name',name,'--network','none','--read-only',
         '--cap-drop','ALL','--security-opt','no-new-privileges','--pids-limit','32',
         '--memory','128m','--memory-swap','128m','--cpus','1','--user','65534:65534',
         '--tmpfs','/tmp:rw,noexec,nosuid,size=8m','--ulimit','nofile=64:64',
         '--mount',f'type=bind,src={RUNNER},dst=/runner.py,readonly',
         IMAGE,'python','-I','-S','/runner.py']
    verdict=13
    try:
        p=subprocess.run(cmd,input=json.dumps({'code':code,'stdin':stdin}),text=True,
                         capture_output=True,timeout=8)
        if p.returncode:
            logging.error('container exit code %d',p.returncode)
        else:
            result=json.loads(p.stdout)
            verdict=11 if result.get('error') else (3 if result['output'].rstrip()==expected.rstrip() else 4)
    except subprocess.TimeoutExpired:
        verdict=5
    except Exception as exc:
        logging.error('judge failure: %s',type(exc).__name__)
    finally:
        try: subprocess.run(['docker','rm','-f',name],capture_output=True,timeout=5)
        except Exception: logging.exception('container cleanup failed')
        with lock: jobs[token]=(verdict,time.monotonic())
        sem.release()

class Handler(BaseHTTPRequestHandler):
    def reply(self,status,obj):
        body=json.dumps(obj).encode()
        self.send_response(status)
        self.send_header('Content-Type','application/json')
        self.send_header('Cache-Control','no-store')
        self.send_header('Content-Length',str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def authenticated(self):
        if not TOKEN or not secrets.compare_digest(self.headers.get('X-Auth-Token',''),TOKEN):
            self.reply(401,{'error':'unauthorized'}); return False
        return True
    def do_GET(self):
        if self.path=='/health': return self.reply(200,{'status':'ok'})
        if not self.authenticated(): return
        if not self.path.startswith('/submissions/'):
            return self.reply(404,{'error':'not found'})
        token=self.path.split('?',1)[0].rsplit('/',1)[-1]
        with lock: record=jobs.get(token)
        return self.reply(200,{'status':{'id':record[0]}}) if record else self.reply(404,{'error':'unknown token'})
    def do_POST(self):
        if self.path.split('?',1)[0]!='/submissions':return self.reply(404,{'error':'not found'})
        if not self.authenticated():return
        try:
            length=int(self.headers.get('Content-Length','0'))
            if not 1<=length<=60000:raise ValueError('request size limit')
            data=json.loads(self.rfile.read(length))
            if int(data.get('language_id',71))!=71:raise ValueError('only Python 3 is supported')
            code=decode(data['source_code']); stdin=decode(data.get('stdin',''))
            expected=decode(data.get('expected_output',''))
            if any(len(x.encode())>limit for x,limit in [(code,32000),(stdin,16000),(expected,16000)]):
                raise ValueError('input size limit')
        except (ValueError,KeyError,TypeError,OverflowError) as exc:
            return self.reply(400,{'error':str(exc)})
        if not sem.acquire(blocking=False):return self.reply(429,{'error':'busy'})
        token=uuid.uuid4().hex
        with lock:
            now=time.monotonic()
            for old in [k for k,(_,t) in jobs.items() if t<now-3600]:del jobs[old]
            jobs[token]=(1,now)
        executor.submit(execute,token,code,stdin,expected)
        return self.reply(201,{'token':token})

if __name__=='__main__':
    if len(TOKEN)<32:raise SystemExit('Set JUDGE_API_TOKEN to a randomly generated 32+ character secret')
    ThreadingHTTPServer(('127.0.0.1',8100),Handler).serve_forever()
