#!/usr/bin/env python3
"""MandakhRank PC judge pilot: Render HTTPS pull queue + restricted Docker Python.

NO listening port, CMS, or RapidAPI account needed. Python 3.10+ / Linux / Docker.
For private educational testing only; Docker-on-WSL is NOT a security boundary
suitable for hostile public submissions on an everyday Windows workstation.
"""
import argparse
import json
import logging
import os
import selectors
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid

LOG = logging.getLogger('mandakhrank.pc.judge')
IMAGE = 'python:3.12-alpine'
MAX_SOURCE_BYTES = 20_000
MAX_STDIN_BYTES = 64 * 1024
MAX_OUTPUT_BYTES = 64 * 1024
MAX_TESTS = 100
WALL_SECONDS = 8


class JudgeInfrastructureError(RuntimeError):
    pass


def api_url():
    url = os.environ.get('MANDAKHRANK_API', '').rstrip('/')
    token = os.environ.get('JUDGE_WORKER_TOKEN', '')
    if not url.startswith('https://') or not token:
        raise JudgeInfrastructureError('Set MANDAKHRANK_API (HTTPS) and JUDGE_WORKER_TOKEN in your private Ubuntu environment')
    return url, token


def request(path, payload, timeout=35):
    base, token = api_url()
    req = urllib.request.Request(
        base + path,
        data=json.dumps(payload).encode('utf-8'),
        headers={'Authorization': 'Bearer ' + token,
                 'Content-Type': 'application/json',
                 'User-Agent': 'MandakhRank-PC-Judge/1.0'},
        method='POST')
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as exc:
        # Keep response bodies off the console, since errors might contain sensitive data.
        raise JudgeInfrastructureError(f'Render {path}: HTTP {exc.code}') from None


def check_connection():
    """Authenticated, nonmutating compatibility check before claiming jobs."""
    status = request('/api/judge/status/', {})
    if status.get('engine') != 'docker_pull' or status.get('protocol') != 'docker-tests-v1':
        raise JudgeInfrastructureError(
            'Render is not running the new docker_pull bridge; deploy the patch and set JUDGE_ENGINE=docker_pull')


def check_docker():
    for args in (['docker', 'info', '--format', '{{.ServerVersion}}'],
                 ['docker', 'image', 'inspect', IMAGE]):
        result = subprocess.run(args, stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, timeout=12, check=False)
        if result.returncode:
            raise JudgeInfrastructureError(
                f'Docker unavailable or image missing. Run: docker pull {IMAGE}')


def _cleanup_container(name):
    try:
        subprocess.run(['docker', 'rm', '-f', name], stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=5, check=False)
    except (OSError, subprocess.TimeoutExpired):
        pass


def run_python(code, stdin, wall_seconds=WALL_SECONDS):
    """Execute ONE test using a new, networkless, resource-limited container.

    Returns (status, stdout text). The container has no mounted source directory,
    no network, no secrets, no Docker socket, and never runs as root.
    """
    if not isinstance(code, str) or len(code.encode('utf-8')) > MAX_SOURCE_BYTES:
        raise ValueError('Unsupported source length')
    if not isinstance(stdin, str) or len(stdin.encode('utf-8')) > MAX_STDIN_BYTES:
        raise ValueError('Test input is too large')

    name = 'mandakh-' + uuid.uuid4().hex[:20]
    cmd = [
        'docker', 'run', '--rm', '--pull=never', '--name', name, '-i',
        '--network', 'none', '--read-only',
        '--cap-drop', 'ALL', '--security-opt', 'no-new-privileges=true',
        '--pids-limit', '32', '--memory', '128m', '--memory-swap', '128m',
        '--cpus', '1', '--user', '65534:65534',
        '--tmpfs', '/tmp:rw,nosuid,nodev,noexec,size=16m',
        '--ulimit', 'nofile=64:64', '--ulimit', 'fsize=1048576:1048576',
        '--workdir', '/tmp', IMAGE, 'python', '-I', '-S', '-B', '-c', code,
    ]
    proc = None
    selected = selectors.DefaultSelector()
    stdout = bytearray()
    stderr = bytearray()
    stopped = None
    try:
        try:
            proc = subprocess.Popen(cmd, stdin=subprocess.PIPE,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                    bufsize=0)
        except OSError as exc:
            raise JudgeInfrastructureError(f'Cannot start Docker: {type(exc).__name__}') from exc

        for stream in (proc.stdout, proc.stderr):
            os.set_blocking(stream.fileno(), False)
            selected.register(stream, selectors.EVENT_READ,
                              stdout if stream is proc.stdout else stderr)
        input_data = memoryview(stdin.encode('utf-8'))
        input_cursor = 0
        if input_data:
            os.set_blocking(proc.stdin.fileno(), False)
            selected.register(proc.stdin, selectors.EVENT_WRITE, None)
        else:
            proc.stdin.close()

        deadline = time.monotonic() + wall_seconds
        while selected.get_map() or proc.poll() is None:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                stopped = 'Time Limit Exceeded'
                break
            for key, _ in selected.select(min(remaining, .15)):
                stream = key.fileobj
                if key.data is None:  # write only the bounded testcase stdin
                    try:
                        written = os.write(stream.fileno(), input_data[input_cursor:input_cursor + 16384])
                        input_cursor += written
                    except BrokenPipeError:
                        input_cursor = len(input_data)
                    if input_cursor >= len(input_data):
                        selected.unregister(stream)
                        stream.close()
                    continue
                try:
                    chunk = os.read(stream.fileno(), 8192)
                except BlockingIOError:
                    continue
                if not chunk:
                    selected.unregister(stream)
                    continue
                target = key.data
                if len(target) + len(chunk) > MAX_OUTPUT_BYTES:
                    stopped = 'Output Limit Exceeded'
                    break
                target.extend(chunk)
            if stopped:
                break

        if stopped:
            _cleanup_container(name)
            return stopped, ''
        proc.wait(timeout=2)
        if proc.returncode == 125:
            raise JudgeInfrastructureError('Docker runtime failed (exit 125); inspect Docker Desktop')
        if proc.returncode != 0:
            error = stderr.decode('utf-8', 'replace')
            if 'SyntaxError:' in error or 'IndentationError:' in error:
                return 'Compilation Error', ''
            # OOM kills may exit 137, but that exit code is not definitive.
            return 'Runtime Error', ''
        return 'OK', stdout.decode('utf-8', errors='replace')
    finally:
        selected.close()
        if proc is not None:
            if proc.poll() is None:
                _cleanup_container(name)
                proc.kill()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
                proc.wait()
            for stream in (proc.stdin, proc.stdout, proc.stderr):
                if stream is not None and not stream.closed:
                    stream.close()


def normalized(text):
    # Similar to common programming-judge policy: disregard trailing whitespace.
    return '\n'.join(line.rstrip() for line in text.replace('\r\n', '\n').split('\n')).strip()


def evaluate(job, run=run_python, heartbeat=request):
    tests = job.get('tests')
    code = job.get('code')
    if not isinstance(tests, list) or not 1 <= len(tests) <= MAX_TESTS:
        raise ValueError('Invalid private test snapshot')
    if not isinstance(code, str):
        raise ValueError('Missing code')
    if job.get('expected_tests') != len(tests):
        raise ValueError('Test snapshot count mismatch')
    passed = 0
    status = 'Accepted'
    key = {'id': job['id'], 'claim_key': job['claim_key']}
    for testcase in tests:
        if not isinstance(testcase, dict) or not isinstance(testcase.get('stdin'), str) or not isinstance(testcase.get('expected'), str):
            raise ValueError('Malformed test snapshot')
        heartbeat('/api/judge/heartbeat/', key)
        outcome, result = run(code, testcase['stdin'])
        if outcome != 'OK':
            status = outcome
            break
        if normalized(result) != normalized(testcase['expected']):
            status = 'Wrong Answer'
            break
        passed += 1
    return {'status': status, 'passed': passed, 'total': len(tests)}


def self_test():
    code = 'a,b = map(int,input().split())\nprint(a+b)'
    test = {'id': 1, 'claim_key': 'local', 'code': code, 'expected_tests': 2,
            'tests': [{'stdin': '3 7\n', 'expected': '10\n'},
                      {'stdin': '-8 3\n', 'expected': '-5\n'}]}
    result = evaluate(test, heartbeat=lambda *args: None)
    if result != {'status': 'Accepted', 'passed': 2, 'total': 2}:
        raise JudgeInfrastructureError(f'Local self-test did not pass: {result}')
    LOG.info('Local Docker test passed: Accepted 2/2')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--check', action='store_true', help='Verify Docker image and Render authentication without claiming work')
    parser.add_argument('--self-test', action='store_true', help='Evaluate sample Python directly in Docker without using Render')
    parser.add_argument('--once', action='store_true', help='Process at most one queued submission, then exit')
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s: %(message)s')

    check_docker()
    if args.self_test:
        self_test()
        return
    check_connection()
    LOG.info('Docker and MandakhRank Render authentication OK')
    if args.check:
        return
    while True:
        job = None
        try:
            job = request('/api/judge/claim/', {}).get('job')
            if job is None:
                if args.once:
                    LOG.info('No queued submission')
                    return
                time.sleep(3)
                continue
            LOG.info('Judging MandakhRank submission #%s (%s tests)', job['id'], job.get('expected_tests'))
            verdict = evaluate(job)
            request('/api/judge/complete/', {'id': job['id'], 'claim_key': job['claim_key'], **verdict})
            LOG.info('Completed #%s: %s %s/%s', job['id'], verdict['status'], verdict['passed'], verdict['total'])
        except KeyboardInterrupt:
            LOG.info('Worker stopped')
            return
        except (OSError, ValueError, RuntimeError, TimeoutError) as exc:
            LOG.error('Worker error: %s', type(exc).__name__ if not str(exc) else str(exc)[:180])
            if job:
                try:
                    request('/api/judge/release/', {'id': job['id'], 'claim_key': job['claim_key']})
                except Exception:
                    pass
            if not args.once:
                time.sleep(6)
        if args.once:
            return


if __name__ == '__main__':
    try:
        main()
    except (JudgeInfrastructureError, OSError, subprocess.TimeoutExpired) as exc:
        sys.exit(str(exc))
