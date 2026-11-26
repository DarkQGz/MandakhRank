"""Capstones are separate from competitive problems. Never execute student code here."""
import json
from datetime import timedelta
from functools import lru_cache
from pathlib import Path

from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

from .models import Course, CourseCompletion, LessonCompletion, Problem, ProjectAttempt, Submission
from .practice import current_user, payload, response


@lru_cache(maxsize=1)
def bank():
    return {row['course']: row for row in json.loads(Path(__file__).with_name('project_bank.json').read_text(encoding='utf-8'))}


def unlocked(user, course):
    if not user or not CourseCompletion.objects.filter(user=user, course=course).exists():
        return False
    lessons = course.lessons.filter(published=True)
    return lessons.exists() and not lessons.exclude(pk__in=LessonCompletion.objects.filter(user=user).values('lesson_id')).exists()


def attempts(user, course, row):
    return ProjectAttempt.objects.filter(user=user, course=course, project_key=row['key'], mode=row['mode']).select_related('submission', 'course')


def passed(a):
    if a.mode == 'review':
        return a.review_status == 'approved' and a.reviewed_at is not None
    s = a.submission
    row = bank().get(a.course.title)
    return bool(row and row['mode'] == 'python' and row['key'] == a.project_key and s and s.status == 'Accepted' and s.total == len(row['tests']) and s.passed == s.total)


def status(a):
    if a.mode == 'review':
        return {'pending': 'Review Pending', 'approved': 'Approved' if passed(a) else 'Review Pending', 'rejected': 'Needs Revision'}[a.review_status]
    s = a.submission
    return s.status if s and (s.status != 'Accepted' or passed(a)) else 'Judge Error'


def attempt_data(a):
    s = a.submission
    return dict(id=a.pk, status=status(a), passed=passed(a), tests_passed=s.passed if s else None,
                tests_total=s.total if s else None, feedback=a.feedback if a.mode == 'review' else '',
                created_at=a.created_at.isoformat())


def summary(user):
    """Only verified completion metadata may appear on another user's profile."""
    completed = {}
    for a in ProjectAttempt.objects.filter(user=user, course__published=True).select_related('course', 'submission').order_by('id'):
        row = bank().get(a.course.title)
        if row and a.project_key == row['key'] and a.mode == row['mode'] and a.project_key not in completed and passed(a):
            date = a.reviewed_at if a.mode == 'review' else a.submission.updated_at
            completed[a.project_key] = dict(title=row['title'], course=a.course.title, mode=a.mode, completed_at=date.isoformat())
    return dict(count=len(completed), total=len(bank()), completed=list(reversed(list(completed.values()))))


def public_data(row):
    data = {key: row[key] for key in ('key', 'title', 'goal', 'requirements', 'contract', 'starter', 'mode')}
    if row['mode'] == 'python':
        data.update(sample_input=row['tests'][0]['stdin'], sample_output=row['tests'][0]['expected'], test_count=len(row['tests']))
    return data


def transport(row):
    # The 300 published problems are never altered. The unique reserved name
    # identifies a private queue transport; no TestCase rows need to be seeded.
    p, _ = Problem.objects.get_or_create(title='[MR CAPSTONE] ' + row['key'], defaults=dict(
        description='Private capstone judge transport. Do not publish.', difficulty='Хялбар', topic='Capstone',
        points=0, sample_input='', sample_output='', published=False))
    if p.published or p.points != 0 or p.topic != 'Capstone' or p.description != 'Private capstone judge transport. Do not publish.':
        raise ValueError('Private transport conflict')
    return p


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def project(request, course_id):
    course = Course.objects.filter(pk=course_id, published=True).first()
    row = bank().get(course.title) if course else None
    if not row:
        return response({'error': 'Энэ сургалтад төсөл бэлэн биш байна.'}, 404)
    user = current_user(request)
    if request.method == 'GET':
        records = attempts(user, course, row) if user else None
        history = list(records[:10]) if records is not None else []
        # Check all earlier attempts, not only the most recent ten.
        complete = any(passed(a) for a in records) if records is not None else False
        return response(dict(project=public_data(row), course=course.title, authenticated=user is not None,
                             unlocked=unlocked(user, course), completed=complete, attempts=[attempt_data(a) for a in history],
                             latest_source=(history[0].submission.code if history[0].mode == 'python' and history[0].submission else history[0].source) if history else None))
    if not user:
        return response({'error': 'Эхлээд нэвтэрнэ үү.'}, 401)
    if not unlocked(user, course):
        return response({'error': 'Бүх хичээл болон нэгдсэн шалгалтад тэнцсэний дараа төслөө илгээнэ үү.'}, 403)
    data = payload(request)
    source = data.get('source') if isinstance(data, dict) else None
    try:
        valid = isinstance(source, str) and bool(source.strip()) and '\x00' not in source and len(source.encode('utf-8')) <= 20000
    except UnicodeEncodeError:
        valid = False
    if not valid:
        return response({'error': 'Эх код эсвэл тайлан хоосон, буруу эсвэл 20 KB-аас их байна.'}, 400)
    if row['mode'] == 'python' and (settings.JUDGE_ENGINE != 'docker_pull' or not settings.JUDGE_WORKER_TOKEN):
        return response({'error': 'Python judge одоогоор тохируулагдаагүй байна.'}, 503)
    with transaction.atomic():
        get_user_model().objects.select_for_update().get(pk=user.pk)
        previous = attempts(user, course, row)
        if any(passed(a) for a in previous):
            return response({'error': 'Та энэ төслийг аль хэдийн дуусгасан.'}, 409)
        if previous.filter(review_status='pending').exists() and row['mode'] == 'review':
            return response({'error': 'Өмнөх төсөл шалгагдаж байна.'}, 409)
        if previous.filter(submission__status__in=['Queued', 'Running']).exists():
            return response({'error': 'Өмнөх төслийн дүн гарахыг хүлээнэ үү.'}, 409)
        cutoff = timezone.now() - timedelta(hours=1)
        if ProjectAttempt.objects.filter(user=user, created_at__gt=cutoff).count() >= 10:
            return response({'error': 'Нэг цагт 10 хүртэл төсөл илгээх боломжтой.'}, 429)
        if row['mode'] == 'python':
            if Submission.objects.filter(user=user, status__in=['Queued', 'Running']).count() >= 3 or Submission.objects.filter(user=user, created_at__gt=cutoff).count() >= 30:
                return response({'error': 'Илгээлтийн хязгаарт хүрсэн байна. Түр хүлээнэ үү.'}, 429)
            try:
                p = transport(row)
            except ValueError:
                return response({'error': 'Төслийн judge тохиргоог админ шалгах шаардлагатай.'}, 503)
            s = Submission.objects.create(user=user, problem=p, code=source, test_snapshot=row['tests'], total=len(row['tests']))
            a = ProjectAttempt.objects.create(user=user, course=course, project_key=row['key'], mode='python', submission=s)
        else:
            a = ProjectAttempt.objects.create(user=user, course=course, project_key=row['key'], mode='review', source=source)
    return response({'attempt': attempt_data(a)}, 201)


def course_card(user, course):
    row = bank().get(course.title)
    if not row:
        return None
    return dict(title=row['title'], goal=row['goal'], mode=row['mode'], unlocked=unlocked(user, course),
                completed=bool(user and any(passed(a) for a in attempts(user, course, row))))
