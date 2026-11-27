"""Classrooms reuse existing completion records without mutating them."""
import secrets
from datetime import timedelta, timezone as dt_timezone
from collections import defaultdict
from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import Min, Max, Count
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from .models import (Classroom, ClassroomMember, ClassroomAssignment, ClassroomTeacher, Course, Lesson, Problem,
                     CourseCompletion, LessonCompletion, Submission, ProjectAttempt)
from .practice import current_user, payload, response
from .projects import bank, passed
from .classroom_rules import assignment_status, parse_deadline, make_csv

MAX_MEMBERS = 100
MAX_ASSIGNMENTS = 60
MAX_CLASSES = 30
KINDS = ('lesson', 'course', 'problem', 'project')


def teacher(user):
    return bool(user and (user.is_superuser or ClassroomTeacher.objects.filter(user=user).exists()))


def fail(message, status=400):
    return response({'error': message}, status)


def text(data, key, length, required=True):
    v = data.get(key, '')
    if not isinstance(v, str) or len(v) > length or '\x00' in v or (required and not v.strip()):
        raise ValueError('Мэдээллийн урт эсвэл утга буруу байна.')
    # Reject invalid surrogate sequences before database writes.
    try:
        v.encode('utf-8')
    except UnicodeEncodeError:
        raise ValueError('Тэмдэгт буруу байна.')
    return v.strip()


def new_code():
    return secrets.token_hex(8).upper()


def card(c, owner):
    data = dict(id=c.pk, name=c.name, description=c.description, archived=c.archived,
                owner=c.owner.username, managing=owner)
    if owner:
        data['join_code'] = c.join_code
    return data


def target_catalog():
    courses = list(Course.objects.filter(published=True).values('id', 'title'))
    return {
        'course': [dict(r, course_id=r['id']) for r in courses],
        'lesson': [dict(id=l.pk, title=f'{l.course.title} / {l.title}', course_id=l.course_id)
                   for l in Lesson.objects.filter(published=True, course__published=True).select_related('course')],
        'problem': list(Problem.objects.filter(published=True).values('id', 'title')),
        'project': [dict(id=r['id'], title=bank()[r['title']]['title'], course_id=r['id'])
                    for r in courses if r['title'] in bank()],
    }


def access(user, c):
    managing = c.owner_id == user.pk and teacher(user)
    member = ClassroomMember.objects.filter(classroom=c, user=user).exists()
    return managing, member


def completions(user_ids, assignments):
    """One query per kind, with first recorded pass dates; no private code returned."""
    dates = {}
    targets = {k: {a.target_id for a in assignments if a.kind == k} for k in KINDS}
    for kind, model, field, date in [('lesson', LessonCompletion, 'lesson_id', 'completed_at'),
                                     ('course', CourseCompletion, 'course_id', 'completed_at'),
                                     ('problem', Submission, 'problem_id', 'updated_at')]:
        if not targets[kind] or not user_ids:
            continue
        qs = model.objects.filter(user_id__in=user_ids, **{field+'__in': targets[kind]})
        if kind == 'problem':
            qs = qs.filter(status='Accepted', project_attempt__isnull=True)
        for row in qs.order_by().values('user_id', field).annotate(first=Min(date)):
            dates[(row['user_id'], kind, row[field])] = row['first']
    # The existing course screen requires both the final pass and every published lesson.
    if targets['course'] and user_ids:
        required = dict(Lesson.objects.filter(course_id__in=targets['course'], published=True)
                        .order_by().values_list('course_id').annotate(n=Count('pk')))
        completed = {(r['user_id'], r['lesson__course_id']): r for r in
                     LessonCompletion.objects.filter(user_id__in=user_ids, lesson__course_id__in=targets['course'], lesson__published=True)
                     .order_by().values('user_id', 'lesson__course_id').annotate(n=Count('pk'), last=Max('completed_at'))}
        for key in [k for k in dates if k[1] == 'course']:
            r = completed.get((key[0], key[2]))
            if not r or r['n'] != required.get(key[2], 0):
                del dates[key]
            else:
                dates[key] = max(dates[key], r['last'])
    if targets['project'] and user_ids:
        for a in ProjectAttempt.objects.filter(user_id__in=user_ids, course_id__in=targets['project']).select_related('course', 'submission'):
            row = bank().get(a.course.title)
            if not row or a.project_key != row['key'] or a.mode != row['mode'] or not passed(a):
                continue
            date = a.reviewed_at if a.mode == 'review' else a.submission.updated_at
            key = (a.user_id, 'project', a.course_id)
            if key not in dates or date < dates[key]:
                dates[key] = date
    return dates


def detail_data(c, user, managing):
    rows = list(c.assignments.filter(archived=False))
    members = list(c.members.select_related('user').order_by('user__username')) if managing else []
    ids = [m.user_id for m in members] if managing else [user.pk]
    dates = completions(ids, rows)
    catalog = target_catalog()
    available = {(k, x['id']): x for k, items in catalog.items() for x in items}
    now = timezone.now()
    out = card(c, managing)
    out['assignments'] = []
    for a in rows:
        target = available.get((a.kind, a.target_id))
        item = dict(id=a.pk, title=a.title, instructions=a.instructions, kind=a.kind,
                    target_id=a.target_id, target_title=a.target_title, course_id=target.get('course_id') if target else None,
                    available=target is not None, due_at=a.due_at.isoformat() if a.due_at else None,
                    created_at=a.created_at.isoformat())
        def result(uid):
            date = dates.get((uid, a.kind, a.target_id))
            return dict(status=assignment_status(date, a.due_at, a.created_at, target is not None, now),
                        completed_at=date.isoformat() if date else None)
        if managing:
            item['results'] = [dict(user_id=m.user_id, username=m.user.username, **result(m.user_id)) for m in members]
        else:
            item.update(result(user.pk))
        out['assignments'].append(item)
    if managing:
        out['members'] = [dict(user_id=m.user_id, username=m.user.username, joined_at=m.joined_at.isoformat()) for m in members]
    return out


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def classrooms(request):
    user = current_user(request)
    if not user:
        return fail('Эхлээд нэвтэрнэ үү.', 401)
    if request.method == 'GET':
        owned = Classroom.objects.filter(owner=user).select_related('owner') if teacher(user) else []
        joined = Classroom.objects.filter(members__user=user).select_related('owner')
        return response(dict(teacher=teacher(user), owned=[card(c, True) for c in owned], joined=[card(c, False) for c in joined]))
    data = payload(request)
    if data is None:
        return fail('JSON буруу байна.')
    action = data.get('action')
    try:
        if action == 'create':
            if not teacher(user):
                return fail('Багшийн эрх шаардлагатай.', 403)
            name, desc = text(data, 'name', 100), text(data, 'description', 500, False)
            with transaction.atomic():
                get_user_model().objects.select_for_update().get(pk=user.pk)
                if Classroom.objects.filter(owner=user).count() >= MAX_CLASSES:
                    return fail('Ангийн тооны хязгаарт хүрсэн байна.', 409)
                c = Classroom.objects.create(owner=user, name=name, description=desc, join_code=new_code())
            return response({'classroom': card(c, True)}, 201)
        if action == 'join':
            code = text(data, 'code', 24).upper()
            with transaction.atomic():
                get_user_model().objects.select_for_update().get(pk=user.pk)
                c = Classroom.objects.select_for_update().filter(join_code=code, archived=False).first()
                if not c or not teacher(c.owner) or not c.owner.is_active:
                    return fail('Ангийн код буруу эсвэл анги хаалттай.', 404)
                if c.owner_id == user.pk:
                    return fail('Та энэ ангийн багш байна.', 409)
                if not c.members.filter(user=user).exists():
                    if c.members.count() >= MAX_MEMBERS or ClassroomMember.objects.filter(user=user).count() >= MAX_CLASSES:
                        return fail('Гишүүнчлэлийн хязгаарт хүрсэн байна.', 409)
                    ClassroomMember.objects.create(classroom=c, user=user)
            return response({'classroom': card(c, False)})
    except ValueError as exc:
        return fail(str(exc))
    return fail('Үйлдэл буруу байна.')


@require_http_methods(['GET'])
def classroom_targets(request):
    user = current_user(request)
    if not user:
        return fail('Эхлээд нэвтэрнэ үү.', 401)
    if not teacher(user):
        return fail('Багшийн эрх шаардлагатай.', 403)
    return response({'targets': target_catalog()})


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def classroom_detail(request, classroom_id):
    user = current_user(request)
    if not user:
        return fail('Эхлээд нэвтэрнэ үү.', 401)
    if request.method == 'GET':
        c = Classroom.objects.filter(pk=classroom_id).select_related('owner').first()
        if not c:
            return fail('Анги олдсонгүй.', 404)
        managing, member = access(user, c)
        if not (managing or member):
            return fail('Анги олдсонгүй.', 404)
        return response({'classroom': detail_data(c, user, managing)})
    data = payload(request)
    if data is None:
        return fail('JSON буруу байна.')
    action = data.get('action')
    try:
        with transaction.atomic():
            c = Classroom.objects.select_for_update().filter(pk=classroom_id).first()
            if not c:
                return fail('Анги олдсонгүй.', 404)
            managing, member = access(user, c)
            if not (managing or member):
                return fail('Анги олдсонгүй.', 404)
            if action == 'leave' and member and not managing:
                c.members.filter(user=user).delete()
                return response({'ok': True})
            if not managing:
                return fail('Багшийн эрх шаардлагатай.', 403)
            if action in ('archive', 'reopen', 'rotate'):
                if action == 'rotate':
                    c.join_code = new_code()
                    c.save(update_fields=['join_code'])
                else:
                    c.archived = action == 'archive'
                    c.save(update_fields=['archived'])
                return response({'ok': True})
            if action == 'remove_member':
                uid = data.get('user_id')
                if type(uid) is not int or not 0 < uid <= 2**63-1:
                    return fail('Гишүүний дугаар буруу байна.')
                c.members.filter(user_id=uid).delete()
                return response({'ok': True})
            if action == 'archive_assignment':
                aid = data.get('assignment_id')
                if type(aid) is not int or not 0 < aid <= 2**63-1:
                    return fail('Даалгаврын дугаар буруу байна.')
                if not c.assignments.filter(pk=aid).update(archived=True):
                    return fail('Даалгавар олдсонгүй.', 404)
                return response({'ok': True})
            if action == 'assign':
                if c.archived:
                    return fail('Хаалттай ангид даалгавар нэмэхгүй.', 409)
                if c.assignments.filter(archived=False).count() >= MAX_ASSIGNMENTS:
                    return fail('Идэвхтэй даалгаврын хязгаарт хүрсэн байна.', 409)
                kind, target_id = data.get('kind'), data.get('target_id')
                if kind not in KINDS or type(target_id) is not int or not 0 < target_id <= 2**63-1:
                    return fail('Даалгаврын төрөл эсвэл дугаар буруу.')
                target = next((x for x in target_catalog()[kind] if x['id'] == target_id), None)
                if not target:
                    return fail('Сонгосон материал нийтлэгдээгүй эсвэл олдсонгүй.', 404)
                title = text(data, 'title', 120)
                instructions = text(data, 'instructions', 2000, False)
                try:
                    due = parse_deadline(data.get('due_at'))
                    if due:
                        due = due.astimezone(dt_timezone.utc)
                        now = timezone.now()
                        if not now < due <= now + timedelta(days=366*5):
                            raise ValueError()
                except (ValueError, OverflowError):
                    return fail('Ирээдүйн хугацааг цагийн бүстэй сонгоно уу.')
                ClassroomAssignment.objects.create(classroom=c, title=title, instructions=instructions, kind=kind,
                                                    target_id=target_id, target_title=target['title'][:300], due_at=due)
                return response({'ok': True}, 201)
    except ValueError as exc:
        return fail(str(exc))
    return fail('Үйлдэл буруу байна.')


@require_http_methods(['GET'])
def classroom_report(request, classroom_id):
    user = current_user(request)
    if not user:
        return fail('Эхлээд нэвтэрнэ үү.', 401)
    c = Classroom.objects.filter(pk=classroom_id, owner=user).select_related('owner').first()
    if not c or not teacher(user):
        return fail('Анги олдсонгүй.', 404)
    data = detail_data(c, user, True)
    rows = [['Анги', 'Оюутан', 'Даалгавар', 'Материал', 'Төлөв', 'Дуусгасан (UTC ISO)', 'Хугацаа (UTC ISO)']]
    labels = {'done': 'Хугацаандаа', 'prior': 'Өмнө нь дуусгасан', 'late': 'Хоцорсон', 'pending': 'Хүлээгдэж буй', 'overdue': 'Хугацаа хэтэрсэн', 'unavailable': 'Материал байхгүй'}
    for a in data['assignments']:
        for r in a['results']:
            rows.append([c.name, r['username'], a['title'], a['target_title'], labels[r['status']], r['completed_at'], a['due_at']])
    return response({'filename': f'mandakh-class-{c.pk}.csv', 'csv': make_csv(rows)})
