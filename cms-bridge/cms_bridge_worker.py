#!/usr/bin/env python3
"""MandakhRank CMS pilot worker (stdlib-only, Python 3.10+).

The worker connects OUT to Django/Render over HTTPS and IN to a loopback-only
CMS ContestWebServer. Never expose CMS or its privileged dev container.
"""
import argparse
import json
import logging
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

LOG = logging.getLogger('mandakh.cms.worker')


def env(key, default=''):
    return os.environ.get(key, default).strip()


def verify_config():
    endpoint = env('MANDAKHRANK_API').rstrip('/')
    secret = env('JUDGE_WORKER_TOKEN')
    cms = env('CMS_BASE_URL', 'http://127.0.0.1:8888').rstrip('/')
    user = env('CMS_API_USER')
    admin = env('CMS_ADMIN_TOKEN')
    if not (endpoint.startswith('https://') and secret and user and admin):
        raise ValueError('Set MANDAKHRANK_API (HTTPS), JUDGE_WORKER_TOKEN, CMS_API_USER, CMS_ADMIN_TOKEN')
    parsed = urllib.parse.urlsplit(cms)
    if parsed.scheme != 'http' or parsed.hostname not in ('localhost', '127.0.0.1', '::1'):
        raise ValueError('CMS_BASE_URL must be local HTTP loopback, never a public address')
    return endpoint, secret, cms, user, admin


class Api:
    def __init__(self, base, token=None):
        self.base, self.token = base, token

    def request(self, path, payload=None, headers=None, raw=None, content_type=None, timeout=20):
        h = {'User-Agent': 'MandakhRank-CMS-Bridge/0.1'}
        if self.token:
            h['Authorization'] = 'Bearer ' + self.token
        if headers:
            h.update(headers)
        data = None
        if raw is not None:
            data = raw
            h['Content-Type'] = content_type
        elif payload is not None:
            data = json.dumps(payload).encode('utf-8')
            h['Content-Type'] = 'application/json'
        req = urllib.request.Request(self.base + path, data=data, headers=h)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as response:
                body = response.read(1024 * 1024)
                return json.loads(body)
        except urllib.error.HTTPError as exc:
            # Never log response bodies; CMS may include hidden task data.
            raise RuntimeError(f'HTTP {exc.code} from {urllib.parse.urlsplit(self.base).hostname} on {path.split("?")[0]}') from None


def multipart_file(template, code, filename, language):
    boundary = 'mandakh-' + uuid.uuid4().hex
    def part(name, value, file_name=None):
        nonlocal boundary
        result = bytearray(f'--{boundary}\r\n'.encode())
        header = f'Content-Disposition: form-data; name="{name}"'
        if file_name:
            header += f'; filename="{file_name}"'
        result.extend((header + '\r\n').encode())
        if file_name:
            result.extend(b'Content-Type: text/plain\r\n')
        result.extend(b'\r\n')
        result.extend(value.encode('utf-8'))
        result.extend(b'\r\n')
        return result
    body = part(template, code, filename)
    body += part('language', language)
    body += part('override_phase_check', '1')
    body += part('override_max_number', '1')
    body += part('override_min_interval', '1')
    body += f'--{boundary}--\r\n'.encode()
    return bytes(body), f'multipart/form-data; boundary={boundary}'


def cms_auth(cms, username, admin_token):
    fields = urllib.parse.urlencode({'username': username, 'admin_token': admin_token}).encode()
    data = cms.request('/api/login', raw=fields, content_type='application/x-www-form-urlencoded')
    auth = data.get('login_data')
    if not isinstance(auth, str) or not auth:
        raise RuntimeError('CMS impersonation login did not return login_data')
    return {'X-CMS-Authorization': auth}


def cms_tasks(cms, auth):
    data = cms.request('/api/task_list?override_phase_check=1', headers=auth)
    return {t['name']: t for t in data.get('tasks', [])}


def map_verdict(outcomes):
    """Only CMS-reported correctness is eligible for Accepted."""
    if not outcomes:
        return None
    normalized = [str(x).lower() for x in outcomes]
    if all(x == 'correct' for x in normalized):
        return 'Accepted'
    if any('time limit' in x or 'timeout' in x for x in normalized):
        return 'Time Limit Exceeded'
    if any('memory' in x for x in normalized):
        return 'Memory Limit Exceeded'
    if any('compil' in x for x in normalized):
        return 'Compilation Error'
    if any('runtime' in x or 'signal' in x or 'exit' in x or 'crash' in x for x in normalized):
        return 'Runtime Error'
    if any(x in ('not correct', 'wrong answer', 'partially correct', 'incorrect') for x in normalized):
        return 'Wrong Answer'
    # Unknown outcomes should not be silently counted as accepted.
    return 'Judge Error'


def extract_result(data):
    items = data.get('details')
    if not isinstance(items, list):
        return None
    tests = []
    def walk(parts):
        for x in parts:
            if not isinstance(x, dict):
                continue
            if isinstance(x.get('testcases'), list):
                walk(x['testcases'])
            elif 'outcome' in x and x.get('outcome') is not None:
                tests.append(str(x['outcome']))
    walk(items)
    status = map_verdict(tests)
    if status is None:
        return None
    passed = sum(x.lower() == 'correct' for x in tests)
    return {'status': status, 'passed': passed, 'total': len(tests)}


def submit_to_cms(cms, auth, task_name, task, code):
    subformat = task.get('submission_format', [])
    if not isinstance(subformat, list) or len(subformat) != 1 or '%l' not in subformat[0]:
        raise ValueError('Bridge pilot only supports one source-file Batch tasks')
    template = subformat[0]
    filename = template.replace('%l', 'py')
    language = env('CMS_LANGUAGE', 'Python 3 / CPython')
    raw, content_type = multipart_file(template, code, filename, language)
    task_url = urllib.parse.quote(task_name, safe='')
    result = cms.request(
        f'/api/{task_url}/submit?override_phase_check=1', headers=auth,
        raw=raw, content_type=content_type)
    ref = str(result.get('id') or '')
    if not ref:
        raise RuntimeError('CMS submit did not return submission ID')
    return ref


def evaluate_job(render, cms, job, auth, tasks):
    task_name = job['task_name']
    if task_name not in tasks:
        raise ValueError('Mapped task not present in CMS task_list: ' + task_name)
    ref = job.get('cms_submission_id', '')
    key = {'id': job['id'], 'claim_key': job['claim_key']}
    if not ref:
        ref = submit_to_cms(cms, auth, task_name, tasks[task_name], job['code'])
        # Save CMS ID first so a restarted bridge can poll rather than resubmit.
        render.request('/api/judge/heartbeat/', {**key, 'cms_submission_id': ref})
    path = '/api/{}/submissions/{}/full_details?override_phase_check=1'.format(
        urllib.parse.quote(task_name, safe=''), urllib.parse.quote(ref, safe=''))
    deadline = time.monotonic() + int(env('CMS_JOB_TIMEOUT', '300'))
    while time.monotonic() < deadline:
        result = cms.request(path, headers=auth)
        verdict = extract_result(result)
        if verdict and verdict['total'] >= int(job.get('expected_tests') or 1):
            render.request('/api/judge/complete/', {**key, **verdict})
            LOG.info('Completed MandakhRank submission %s: %s %s/%s', job['id'], verdict['status'], verdict['passed'], verdict['total'])
            return
        render.request('/api/judge/heartbeat/', key)
        time.sleep(4)
    raise TimeoutError('CMS did not report complete testcase results within the deadline')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='Check CMS authentication and tasks only')
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')
    endpoint, token, cms_url, user, admin = verify_config()
    render, cms = Api(endpoint, token), Api(cms_url)
    LOG.info('Authenticating with local CMS at %s', cms_url)
    auth = cms_auth(cms, user, admin)
    tasks = cms_tasks(cms, auth)
    LOG.info('CMS ready; task names: %s', ', '.join(tasks))
    if args.check:
        return
    while True:
        job = None
        try:
            response = render.request('/api/judge/claim/', {})
            job = response.get('job')
            if job:
                # A cookie may expire while the bridge is idle.
                auth = cms_auth(cms, user, admin)
                tasks = cms_tasks(cms, auth)
                evaluate_job(render, cms, job, auth, tasks)
            else:
                time.sleep(3)
        except KeyboardInterrupt:
            LOG.info('Stopping worker')
            break
        except (OSError, RuntimeError, ValueError, TimeoutError) as exc:
            LOG.error('Judge bridge failed: %s', type(exc).__name__ if not str(exc) else str(exc)[:250])
            if job:
                try:
                    render.request('/api/judge/release/', {'id': job['id'], 'claim_key': job['claim_key']})
                except Exception:
                    pass
            time.sleep(12)


if __name__ == '__main__':
    try:
        main()
    except (ValueError, RuntimeError) as exc:
        sys.exit(str(exc))
