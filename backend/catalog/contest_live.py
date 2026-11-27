"""Automatic contests on the existing private Docker queue; no worker protocol changes."""
import json
from datetime import timedelta
from uuid import uuid4
from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_GET, require_http_methods
from .models import Contest, ContestProblem, Problem, Submission, TestCase
from .practice import current_user, payload, response
from .classrooms import teacher
from .judge_languages import available_languages
from .contest_rules import scoreboard, PENDING


def engine_ready():
    return settings.JUDGE_ENGINE == 'docker_pull' and bool(settings.JUDGE_WORKER_TOKEN)


def student(user):
    return bool(user and user.is_active and not user.is_staff and not teacher(user))


def snapshot_tests(ids):
    snapshots = {pk: [] for pk in ids}
    for row in TestCase.objects.filter(problem_id__in=ids).order_by('pk').values('problem_id', 'stdin', 'expected'):
        snapshots[row['problem_id']].append({'stdin': row['stdin'], 'expected': row['expected']})
    for cases in snapshots.values():
        if not 1 <= len(cases) <= 100:
            raise ValueError('Автомат тэмцээний бодлого бүр 1–100 нууц тесттэй байна.')
        for case in cases:
            if any(not isinstance(v, str) or '\x00' in v or len(v.encode('utf-8')) > 65536 for v in case.values()):
                raise ValueError('Нууц тестийн хэмжээ эсвэл тэмдэгт буруу байна.')
        if len(json.dumps(cases, ensure_ascii=True).encode('utf-8')) > 1_000_000:
            raise ValueError('Нэг бодлогын нийт нууц тест 1 MB-аас их байна.')
    return snapshots


def create_tasks(contest, ids, problems, snapshots):
    """Caller holds transaction. Private transport is never part of public problem bank."""
    for i, pk in enumerate(ids):
        p = problems[pk]
        transport = Problem.objects.create(title='__contest_' + uuid4().hex,
            description='', sample_input='', sample_output='', points=0, published=False,
            is_contest_transport=True)
        ContestProblem.objects.create(contest=contest, label=chr(65+i), title=p.title,
            statement=p.description, sample_input=p.sample_input, sample_output=p.sample_output,
            points=max(1, p.points), judge_problem=transport, judge_tests=snapshots[pk])


def tasks_for(contest):
    return list(contest.problems.filter(judge_problem__isnull=False).defer('judge_tests').order_by('label', 'pk'))


def attempts_for(contest):
    return Submission.objects.filter(problem__contest_task__contest_id=contest.pk,
        problem__is_contest_transport=True, created_at__gte=contest.starts_at, created_at__lt=contest.ends_at)


def standings_for(contest, tasks=None):
    tasks = tasks if tasks is not None else tasks_for(contest)
    points = {p.pk: p.points for p in tasks}
    attempts = attempts_for(contest).order_by().values_list('pk', 'user_id', 'user__username',
        'problem__contest_task__pk', 'status', 'passed', 'total', 'created_at')
    return scoreboard(attempts.iterator(chunk_size=2000), points, contest.starts_at, contest.ends_at)


def progression_rows(user, now):
    # Automatic achievements use final standings only, never pending results.
    ids = Submission.objects.filter(user=user, status='Accepted', problem__is_contest_transport=True,
        problem__contest_task__contest__auto_judge=True,
        problem__contest_task__contest__published=True,
        problem__contest_task__contest__ends_at__lte=now).order_by().values_list('problem__contest_task__contest_id', flat=True).distinct()
    output = []
    for cid in Contest.objects.filter(pk__in=ids).order_by('pk').values_list('pk', flat=True):
        with transaction.atomic():
            c = Contest.objects.select_for_update().filter(pk=cid, published=True, auto_judge=True, ends_at__lte=now).first()
            if c is None:
                continue
            rows, pending = standings_for(c)
            if not pending and any(r['user_id'] == user.pk and r['score'] > 0 for r in rows):
                output.extend((c.pk, r['participant'], r['score'], r['penalty']) for r in rows)
    return output


def task_data(p):
    return dict(id=p.pk, label=p.label, title=p.title, statement=p.statement,
        input=p.sample_input, output=p.sample_output, points=p.points)


def active(contest, now):
    return contest.starts_at <= now < contest.ends_at


@require_GET
def live(request, contest_id):
    c = Contest.objects.filter(pk=contest_id, published=True, auto_judge=True).first()
    if c is None:
        return response({'error': 'Тэмцээн олдсонгүй.'}, 404)
    user = current_user(request)
    now = timezone.now()
    started = now >= c.starts_at
    ended = now >= c.ends_at
    if ended:
        # Wait for any last admission transaction that held this lock before the deadline.
        with transaction.atomic():
            c = Contest.objects.select_for_update().filter(pk=contest_id, published=True, auto_judge=True).first()
            if c is None:
                return response({'error': 'Тэмцээн олдсонгүй.'}, 404)
            now = timezone.now()
            started, ended = now >= c.starts_at, now >= c.ends_at
            tasks = tasks_for(c) if started else []
            rows, pending = standings_for(c, tasks) if started else ([], 0)
    else:
        tasks = tasks_for(c) if started else []
        rows, pending = standings_for(c, tasks) if started else ([], 0)
    return response(dict(id=c.pk, title=c.title, description=c.description, announcement=c.announcement,
        starts_at=c.starts_at.isoformat(), ends_at=c.ends_at.isoformat(), server_time=now.isoformat(),
        status='Удахгүй' if not started else 'Дууссан' if ended else 'Явагдаж байна',
        problems=[task_data(p) for p in tasks], standings=rows, pending=pending,
        final=ended and not pending, can_submit=active(c, now) and student(user) and engine_ready(),
        signed_in=user is not None, judge_ready=engine_ready()))


def history(c, p, user):
    rows = attempts_for(c).filter(problem_id=p.judge_problem_id, user=user).order_by('-pk').values(
        'id', 'status', 'passed', 'total', 'created_at', 'language')[:100]
    return [dict(r, problem_id=p.pk, created_at=r['created_at'].isoformat()) for r in rows]


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def submissions(request, contest_id, task_id):
    user = current_user(request)
    if not user:
        return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)
    c = Contest.objects.filter(pk=contest_id, published=True, auto_judge=True).first()
    if c is None or timezone.now() < c.starts_at:
        return response({'error': 'Тэмцээн эсвэл бодлого олдсонгүй.'}, 404)
    p = c.problems.filter(pk=task_id, judge_problem__isnull=False).defer('judge_tests').first()
    if p is None:
        return response({'error': 'Тэмцээн эсвэл бодлого олдсонгүй.'}, 404)
    if request.method == 'GET':
        return response({'results': history(c, p, user), 'languages': available_languages(),
            'can_submit': active(c, timezone.now()) and student(user) and engine_ready()})
    if not engine_ready():
        return response({'error': 'Автомат шүүгч бэлэн биш байна.'}, 503)
    data = payload(request)
    if not data or set(data) != {'problem_id', 'code', 'language'} or type(data['problem_id']) is not int or data['problem_id'] != task_id:
        return response({'error': 'Илгээлтийн мэдээлэл буруу.'}, 400)
    code, language = data['code'], data['language']
    try:
        valid = isinstance(code, str) and bool(code.strip()) and '\x00' not in code and len(code.encode('utf-8')) <= 20000
    except UnicodeEncodeError:
        valid = False
    if not valid or not isinstance(language, str) or language not in available_languages():
        return response({'error': 'Код эсвэл програмчлалын хэл буруу.'}, 400)
    with transaction.atomic():
        user = get_user_model().objects.select_for_update().get(pk=user.pk)
        if not student(user) or current_user(request) is None:
            return response({'error': 'Суралцагчийн эрх шаардлагатай.'}, 403)
        c = Contest.objects.select_for_update().filter(pk=contest_id, published=True, auto_judge=True).first()
        if c is None:
            return response({'error': 'Тэмцээн олдсонгүй.'}, 404)
        # This timestamp is admission time, not browser time or worker completion time.
        now = timezone.now()
        if not active(c, now):
            return response({'error': 'Тэмцээний хугацаа дууссан эсвэл эхлээгүй байна.'}, 409)
        p = c.problems.filter(pk=task_id, judge_problem__isnull=False, judge_problem__is_contest_transport=True).first()
        if p is None or not p.judge_tests:
            return response({'error': 'Бодлогын тест бэлэн биш байна.'}, 409)
        # Shared practice/project limits, not a second independent quota.
        qs = Submission.objects.filter(user=user)
        if qs.filter(status__in=PENDING).count() >= 3 or qs.filter(created_at__gt=now-timedelta(hours=1)).count() >= 30:
            return response({'error': 'Илгээлтийн хязгаарт хүрлээ. Түр хүлээнэ үү.'}, 429)
        s = Submission.objects.create(user=user, problem_id=p.judge_problem_id, code=code,
            language=language, test_snapshot=p.judge_tests, total=len(p.judge_tests))
        Submission.objects.filter(pk=s.pk).update(created_at=now)
    return response({'id': s.pk, 'status': s.status}, 201)
