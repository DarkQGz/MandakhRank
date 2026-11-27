"""Account-scoped inbox. Derived activity plus durable announcements/read receipts.

No writes on polling, no judge hooks, no private source or hidden tests selected.
"""
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from .models import (Announcement, NotificationRead, Classroom, ClassroomAssignment,
                     ClassroomMember, Contest, Submission, ProjectAttempt)
from .classrooms import teacher, text
from .practice import current_user, payload, response
from .notification_rules import WINDOW, LIMIT, recent, valid_keys, serialize

VERDICTS = {
    'Accepted': 'Зөв хариу', 'Wrong Answer': 'Буруу хариу',
    'Compilation Error': 'Хөрвүүлэх алдаа', 'Runtime Error': 'Ажиллуулах алдаа',
    'Time Limit Exceeded': 'Хугацаа хэтэрсэн', 'Memory Limit Exceeded': 'Санах ой хэтэрсэн',
    'Output Limit Exceeded': 'Гаралтын хэмжээ хэтэрсэн', 'Judge Error': 'Шүүгчийн алдаа',
}


def fail(message, status=400):
    return response({'error': message}, status)


def member_classes(user):
    return ClassroomMember.objects.filter(user=user, classroom__archived=False).values('classroom_id')


def event(key, at, kind, title, body, target=None, target_id=None, target_title=None, verdict=None):
    return dict(id=key, at=at, kind=kind, title=title, body=body, target=target,
                target_id=target_id, target_title=target_title, verdict=verdict)


def feed(user, now):
    cutoff = now - WINDOW
    classes = member_classes(user)
    events = []
    announcements = Announcement.objects.filter(withdrawn=False, created_at__range=(cutoff, now)).filter(
        Q(classroom__isnull=True) | Q(classroom_id__in=classes)).order_by('-created_at', '-pk').values(
        'pk', 'created_at', 'title', 'body', 'classroom_id', 'classroom__name', 'author__username')[:LIMIT]
    for a in announcements:
        prefix = a['classroom__name'] or 'MandakhRank'
        events.append(event(f"announcement:{a['pk']}", a['created_at'], 'announcement', a['title'],
            f"{prefix} · {a['author__username'] or 'MandakhRank'}\n{a['body']}",
            'classroom' if a['classroom_id'] else None, a['classroom_id'], prefix))
    assignments = ClassroomAssignment.objects.filter(classroom_id__in=classes, archived=False,
        created_at__range=(cutoff, now)).order_by('-created_at', '-pk').values(
        'pk', 'created_at', 'title', 'classroom_id', 'classroom__name', 'due_at')[:LIMIT]
    for a in assignments:
        due = timezone.localtime(a['due_at']).strftime('%Y.%m.%d %H:%M') if a['due_at'] else 'Хугацаагүй'
        events.append(event(f"assignment:{a['pk']}", a['created_at'], 'assignment', 'Шинэ даалгавар: '+a['title'],
            f"{a['classroom__name']} · Дуусах: {due} (УБ)", 'classroom', a['classroom_id'], a['classroom__name']))
    contests = Contest.objects.filter(published=True, starts_at__range=(cutoff, now)).order_by('-starts_at', '-pk').values(
        'pk', 'title', 'starts_at', 'ends_at', 'auto_judge')[:LIMIT]
    for c in contests:
        # Start event is stable even after the competition ends.
        events.append(event(f"contest:{c['pk']}", c['starts_at'], 'contest', 'Тэмцээн: '+c['title'],
            'Тэмцээн дууссан.' if c['ends_at'] <= now else 'Тэмцээн явагдаж байна.',
            'contest' if c['auto_judge'] else None, c['pk'] if c['auto_judge'] else None, c['title']))
    visible = (Q(problem__published=True, project_attempt__isnull=True, problem__is_contest_transport=False)
        | Q(problem__contest_task__contest__published=True, problem__is_contest_transport=True)
        | Q(project_attempt__course__published=True))
    submissions = Submission.objects.filter(user=user, status__in=VERDICTS, updated_at__range=(cutoff, now)).filter(visible).order_by(
        '-updated_at', '-pk').values('pk', 'status', 'updated_at', 'language', 'problem_id', 'problem__title',
        'problem__published', 'problem__is_contest_transport', 'problem__contest_task__title',
        'problem__contest_task__contest_id', 'problem__contest_task__contest__title', 'project_attempt__course__title', 'project_attempt__course_id')[:LIMIT]
    for s in submissions:
        if s['problem__is_contest_transport']:
            title = s['problem__contest_task__title']; target = 'contest'; target_id = s['problem__contest_task__contest_id']; target_title = s['problem__contest_task__contest__title']
        elif s['project_attempt__course_id']:
            title = s['project_attempt__course__title']; target = None; target_id = None; target_title = None
        else:
            title = s['problem__title']; target = 'problem'; target_id = s['problem_id']; target_title = title
        events.append(event(f"submission:{s['pk']}:{s['status']}", s['updated_at'], 'verdict', VERDICTS[s['status']],
            f"{title} · #{s['pk']} · {s['language']}", target, target_id, target_title, s['status']))
    reviews = ProjectAttempt.objects.filter(user=user, mode='review', course__published=True,
        review_status__in=['approved', 'rejected'], reviewed_at__range=(cutoff, now)).order_by('-reviewed_at', '-pk').values(
        'pk', 'course__title', 'review_status', 'reviewed_at')[:LIMIT]
    for r in reviews:
        events.append(event(f"review:{r['pk']}:{r['review_status']}", r['reviewed_at'], 'verdict',
            'Төсөл тэнцсэн' if r['review_status'] == 'approved' else 'Төсөлд засвар шаардлагатай', r['course__title']))
    return recent(events, now)


def inbox_data(user, events):
    keys = [e['id'] for e in events]
    read = set(NotificationRead.objects.filter(user=user, event_key__in=keys).values_list('event_key', flat=True))
    return serialize(events, read)


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def inbox(request):
    user = current_user(request)
    if not user:
        return fail('Эхлээд нэвтэрнэ үү.', 401)
    if request.method == 'GET':
        result = inbox_data(user, feed(user, timezone.now()))
        return response({'unread': result['unread']} if request.GET.get('summary') == '1' else result)
    data = payload(request)
    if not data or set(data) != {'action', 'ids'} or data['action'] not in ('read', 'unread') or not valid_keys(data['ids']):
        return fail('Мэдэгдлийн сонголт буруу байна.')
    with transaction.atomic():
        locked = get_user_model().objects.select_for_update().filter(pk=user.pk, is_active=True).first()
        if locked is None or current_user(request) is None:
            return fail('Эхлээд нэвтэрнэ үү.', 401)
        now = timezone.now()
        events = feed(locked, now)
        allowed = {e['id']: e['at'] for e in events}
        if not set(data['ids']).issubset(allowed):
            return fail('Мэдэгдэл өөрчлөгдсөн. Дахин шинэчилнэ үү.', 409)
        NotificationRead.objects.filter(user=locked, event_at__lt=now-WINDOW).delete()
        if data['action'] == 'read':
            NotificationRead.objects.bulk_create([NotificationRead(user=locked, event_key=k, event_at=allowed[k]) for k in data['ids']], ignore_conflicts=True)
        else:
            NotificationRead.objects.filter(user=locked, event_key__in=data['ids']).delete()
        return response(inbox_data(locked, events))


def managed(user):
    # Global publication is a separate superuser permission; teachers own only their classes.
    return Announcement.objects.filter(Q(classroom__owner=user) | (Q(classroom__isnull=True) if user.is_superuser else Q(pk__in=[])))


def management_data(user):
    rows = managed(user).filter(created_at__gte=timezone.now()-WINDOW).order_by('-created_at', '-pk').values(
        'id', 'title', 'body', 'classroom_id', 'classroom__name', 'created_at', 'withdrawn')[:LIMIT]
    return dict(global_allowed=user.is_superuser,
        classrooms=list(Classroom.objects.filter(owner=user, archived=False).values('id','name')),
        results=[dict(r, created_at=r['created_at'].isoformat()) for r in rows])


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def announcements(request):
    user = current_user(request)
    if not user:
        return fail('Эхлээд нэвтэрнэ үү.', 401)
    if not teacher(user):
        return fail('Багшийн эрх шаардлагатай.', 403)
    if request.method == 'GET':
        return response(management_data(user))
    data = payload(request)
    if not data:
        return fail('Мэдээлэл буруу байна.')
    with transaction.atomic():
        user = get_user_model().objects.select_for_update().get(pk=user.pk)
        if not user.is_active or not teacher(user) or current_user(request) is None:
            return fail('Багшийн эрх шаардлагатай.', 403)
        if data.get('action') == 'publish' and set(data) == {'action','classroom_id','title','body'}:
            cid = data['classroom_id']
            classroom = None
            if cid is None:
                if not user.is_superuser:
                    return fail('Нийтийн зарлалд админы эрх шаардлагатай.', 403)
            else:
                if type(cid) is not int or not 1 <= cid <= 9223372036854775807:
                    return fail('Ангийн дугаар буруу байна.')
                classroom = Classroom.objects.select_for_update().filter(pk=cid, owner=user, archived=False).first()
                if classroom is None:
                    return fail('Анги олдсонгүй.', 404)
            try:
                title = text(data, 'title', 120)
                body = text(data, 'body', 2000)
            except ValueError as exc:
                return fail(str(exc))
            if Announcement.objects.filter(author=user, created_at__gte=timezone.now()-timedelta(days=1)).count() >= 10:
                return fail('24 цагт 10 зарлал нийтлэх боломжтой.', 429)
            Announcement.objects.create(author=user, classroom=classroom, title=title, body=body)
            return response(management_data(user), 201)
        if data.get('action') == 'withdraw' and set(data) == {'action','id'}:
            pk = data['id']
            if type(pk) is not int or not 1 <= pk <= 9223372036854775807:
                return fail('Зарлалын дугаар буруу байна.')
            count = managed(user).filter(pk=pk, withdrawn=False).update(withdrawn=True)
            if not count:
                return fail('Зарлал олдсонгүй.', 404)
            return response(management_data(user))
        return fail('Үйлдэл буруу байна.')
