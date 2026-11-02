"""Private HTTPS pull queue for a PC judge worker (CMS or local Docker).

Only holders of JUDGE_WORKER_TOKEN can retrieve student source and secret tests.
No student-facing endpoints expose those tests.
"""
import hmac
import json
import secrets
from datetime import timedelta

from django.conf import settings
from django.db import connection, transaction
from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST

from .models import Submission

FINAL_STATUSES = {
    'Accepted', 'Wrong Answer', 'Compilation Error', 'Runtime Error',
    'Time Limit Exceeded', 'Memory Limit Exceeded', 'Output Limit Exceeded', 'Judge Error',
}


def reply(body, status=200):
    result = JsonResponse(body, status=status)
    result['Cache-Control'] = 'no-store'
    return result


def get_body(request):
    try:
        value = json.loads(request.body)
    except (ValueError, UnicodeDecodeError):
        return None
    return value if isinstance(value, dict) else None


@csrf_exempt
@require_POST
def endpoint(request, action):
    if settings.JUDGE_ENGINE not in ('cms_pull', 'docker_pull') or not settings.JUDGE_WORKER_TOKEN:
        return reply({'error': 'Worker unavailable'}, 503)
    supplied = request.headers.get('Authorization', '')
    wanted = 'Bearer ' + settings.JUDGE_WORKER_TOKEN
    if not hmac.compare_digest(supplied.encode(), wanted.encode()):
        return reply({'error': 'Unauthorized'}, 401)
    data = get_body(request)
    if data is None:
        return reply({'error': 'Expected JSON object'}, 400)

    if action == 'status':
        return reply({'engine': settings.JUDGE_ENGINE,
                      'protocol': 'docker-tests-v1' if settings.JUDGE_ENGINE == 'docker_pull' else 'cms-v1'})

    if action == 'claim':
        # A single worker is the intended initial deployment. Row locking also
        # allows a future multi-worker deployment under PostgreSQL.
        with transaction.atomic():
            cutoff = timezone.now() - timedelta(seconds=max(60, settings.CMS_LEASE_SECONDS))
            Submission.objects.filter(status='Running', updated_at__lt=cutoff, cms_attempts__gte=3).update(
                status='Judge Error', cms_claim_key='', updated_at=timezone.now())
            Submission.objects.filter(status='Running', updated_at__lt=cutoff, cms_attempts__lt=3).update(
                status='Queued', cms_claim_key='', updated_at=timezone.now())
            qs = Submission.objects.select_related('problem').filter(status='Queued').order_by('id')
            if connection.features.has_select_for_update_skip_locked:
                qs = qs.select_for_update(skip_locked=True)
            elif connection.features.has_select_for_update:
                qs = qs.select_for_update()
            s = qs.first()
            if s is None:
                return reply({'job': None})
            if settings.JUDGE_ENGINE == 'cms_pull' and not s.problem.cms_task_name:
                # Badly configured queued jobs must not silently consume an
                # unrelated CMS problem, nor block the worker indefinitely.
                s.status = 'Judge Error'
                s.updated_at = timezone.now()
                s.save(update_fields=['status', 'updated_at'])
                return reply({'job': None})
            if s.cms_attempts >= 3:
                s.status = 'Judge Error'
                s.cms_claim_key = ''
                s.updated_at = timezone.now()
                s.save(update_fields=['status', 'cms_claim_key', 'updated_at'])
                return reply({'job': None})
            s.status = 'Running'
            s.cms_claim_key = secrets.token_hex(32)
            s.cms_attempts += 1
            s.updated_at = timezone.now()
            s.save(update_fields=['status', 'cms_claim_key', 'cms_attempts', 'updated_at'])
            job = {
                'id': s.id, 'claim_key': s.cms_claim_key,
                'task_name': s.problem.cms_task_name,
                'code': s.code, 'cms_submission_id': s.cms_submission_id,
                'attempt': s.cms_attempts, 'expected_tests': s.total,
            }
            if settings.JUDGE_ENGINE == 'docker_pull':
                # Tests are only sent to the authenticated private worker.
                # Never include them in the browser's /api/submissions/ response.
                job['tests'] = s.test_snapshot
            return reply({'job': job})

    if action not in ('heartbeat', 'complete', 'release'):
        return reply({'error': 'Not found'}, 404)
    if type(data.get('id')) is not int or not isinstance(data.get('claim_key'), str):
        return reply({'error': 'Invalid claim'}, 400)
    with transaction.atomic():
        qs = Submission.objects.select_for_update().filter(
            pk=data['id'], status='Running', cms_claim_key=data['claim_key'])
        s = qs.first()
        if s is None:
            return reply({'error': 'Expired or invalid claim'}, 409)

        if action == 'heartbeat':
            ref = data.get('cms_submission_id')
            if ref is not None:
                if not isinstance(ref, str) or not 1 <= len(ref) <= 128:
                    return reply({'error': 'Invalid CMS ID'}, 400)
                if s.cms_submission_id and s.cms_submission_id != ref:
                    return reply({'error': 'CMS ID cannot be changed'}, 409)
                s.cms_submission_id = ref
            s.updated_at = timezone.now()
            s.save(update_fields=['cms_submission_id', 'updated_at'])
            return reply({'ok': True})

        if action == 'release':
            # The caller may retry an unavailable CMS service. If CMS accepted
            # the code, cms_submission_id persists for polling after recovery.
            s.status = 'Queued' if s.cms_attempts < 3 else 'Judge Error'
            s.cms_claim_key = ''
            s.updated_at = timezone.now()
            s.save(update_fields=['status', 'cms_claim_key', 'updated_at'])
            return reply({'status': s.status})

        status = data.get('status')
        passed = data.get('passed')
        total = data.get('total')
        if status not in FINAL_STATUSES or type(passed) is not int or type(total) is not int:
            return reply({'error': 'Invalid result'}, 400)
        if not (0 <= passed <= total <= 10000):
            return reply({'error': 'Invalid counts'}, 400)
        if status == 'Accepted' and (total == 0 or passed != total):
            return reply({'error': 'An accepted result must pass all tests'}, 400)
        s.status, s.passed, s.total = status, passed, total
        s.cms_claim_key = ''
        s.updated_at = timezone.now()
        s.save(update_fields=['status', 'passed', 'total', 'cms_claim_key', 'updated_at'])
        return reply({'ok': True})
