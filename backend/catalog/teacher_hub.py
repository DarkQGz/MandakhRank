"""Teacher workspace. Authorization always uses the Phase 5 teacher role."""
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.db import transaction
from django.contrib.admin.models import LogEntry, ADDITION, CHANGE
from django.contrib.contenttypes.models import ContentType
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from .classrooms import teacher, text, fail
from .models import Classroom, ClassroomAssignment, ClassroomMember, Contest, ContestProblem, ContestResult, Problem
from django.db.models import Prefetch
from .practice import current_user, payload, response
from .contest_live import engine_ready, snapshot_tests, create_tasks


def integer(value, low, high):
    if type(value) is not int or not low <= value <= high:
        raise ValueError('Тоон утга буруу байна.')
    return value


def public_role(user):
    return 'teacher' if teacher(user) else 'student'


def audit(user, obj, message, flag=CHANGE):
    LogEntry.objects.create(user=user, content_type=ContentType.objects.get_for_model(obj),
                            object_id=str(obj.pk), object_repr=str(obj)[:200],
                            action_flag=flag, change_message=message)


def contest_card(c):
    return dict(id=c.pk, title=c.title, description=c.description, status=c.status, auto_judge=c.auto_judge,
                starts_at=c.starts_at.isoformat(), ends_at=c.ends_at.isoformat(),
                problems=[dict(id=p.pk, label=p.label, title=p.title, points=p.points,
                               results=[dict(participant=r.participant, score=r.score, penalty=r.penalty)
                                        for r in p.results.all()]) for p in c.problems.all()])


@csrf_exempt
@require_http_methods(['GET', 'POST'])
def workspace(request):
    user = current_user(request)
    if not user:
        return fail('Эхлээд нэвтэрнэ үү.', 401)
    if not teacher(user):
        return fail('Багшийн эрх шаардлагатай.', 403)
    if request.method == 'GET':
        rooms = Classroom.objects.filter(owner=user, archived=False)
        own = Contest.objects.filter(organizer=user, published=True).prefetch_related(Prefetch('problems', queryset=ContestProblem.objects.defer('judge_tests').prefetch_related('results')))
        return response(dict(classrooms=rooms.count(),
                             students=ClassroomMember.objects.filter(classroom__in=rooms, user__is_active=True).values('user_id').distinct().count(),
                             assignments=ClassroomAssignment.objects.filter(classroom__in=rooms, archived=False).count(),
                             contests=[contest_card(c) for c in own[:100]],
                             problems=list(Problem.objects.filter(published=True).values('id','title','difficulty','points'))))
    data = payload(request)
    if data is None:
        return fail('JSON буруу байна.')
    try:
        with transaction.atomic():
            # Serialize teacher mutations and recheck permission after lock.
            user = get_user_model().objects.select_for_update().get(pk=user.pk)
            if not user.is_active or not teacher(user):
                return fail('Багшийн эрх шаардлагатай.', 403)
            action = data.get('action')
            now = timezone.now()
            if action == 'create':
                title = text(data, 'title', 200)
                description = text(data, 'description', 2000, False)
                delay = integer(data.get('delay_minutes'), 0, 43200)
                duration = integer(data.get('duration_minutes'), 5, 1440)
                ids = data.get('problem_ids')
                if not isinstance(ids, list) or not 1 <= len(ids) <= 12:
                    raise ValueError('1–12 бодлого сонгоно уу.')
                for pk in ids:
                    integer(pk, 1, 9223372036854775807)
                if len(set(ids)) != len(ids):
                    raise ValueError('Бодлого давхардсан байна.')
                problems = Problem.objects.filter(pk__in=ids, published=True).in_bulk()
                if len(problems) != len(ids):
                    return fail('Нийтэлсэн бодлого олдсонгүй.', 404)
                if Contest.objects.filter(organizer=user, ends_at__gt=now).count() >= 20:
                    return fail('Идэвхтэй болон төлөвлөсөн тэмцээн 20 хүртэл байна.', 409)
                automatic = data.get('auto_judge', False)
                if type(automatic) is not bool:
                    return fail('Тэмцээний төрөл буруу байна.')
                if automatic and not engine_ready():
                    return fail('Автомат шүүгч тохируулагдаагүй байна.', 503)
                snapshots = snapshot_tests(ids) if automatic else None
                start = timezone.now() + timedelta(minutes=delay)
                c = Contest.objects.create(organizer=user, title=title, description=description,
                                           starts_at=start, ends_at=start+timedelta(minutes=duration), published=True, auto_judge=automatic)
                if automatic:
                    create_tasks(c, ids, problems, snapshots)
                else:
                    ContestProblem.objects.bulk_create([ContestProblem(contest=c,label=chr(65+i),title=problems[pk].title,
                        statement=problems[pk].description,sample_input=problems[pk].sample_input,
                        sample_output=problems[pk].sample_output,points=max(1,problems[pk].points)) for i,pk in enumerate(ids)])
                audit(user, c, 'Teacher published contest', ADDITION)
                return response({'contest': contest_card(c)}, 201)
            if action not in ('start', 'end', 'result'):
                return fail('Үйлдэл буруу байна.')
            pk = integer(data.get('contest_id'), 1, 9223372036854775807)
            c = Contest.objects.select_for_update().filter(pk=pk, organizer=user, published=True).first()
            if c is None:
                return fail('Тэмцээн олдсонгүй.', 404)
            now = timezone.now()  # after obtaining the same contest lock as admission
            if action == 'start':
                if now >= c.starts_at:
                    return fail('Зөвхөн удахгүй эхлэх тэмцээнийг эхлүүлнэ.', 409)
                duration = c.ends_at - c.starts_at
                c.starts_at = now
                c.ends_at = now + duration
                c.save(update_fields=['starts_at','ends_at'])
                audit(user, c, 'Teacher started contest early')
            elif action == 'end':
                if not c.starts_at < now < c.ends_at:
                    return fail('Зөвхөн явагдаж буй тэмцээнийг дуусгана.', 409)
                c.ends_at = now
                c.save(update_fields=['ends_at'])
                audit(user, c, 'Teacher ended contest early')
            else:
                if c.auto_judge:
                    return fail('Автомат тэмцээний дүнг гараар өөрчлөх боломжгүй.', 409)
                if now < c.starts_at:
                    return fail('Тэмцээн хараахан эхлээгүй.', 409)
                p = c.problems.filter(pk=integer(data.get('problem_id'),1,9223372036854775807)).first()
                if p is None:
                    return fail('Тэмцээний бодлого олдсонгүй.', 404)
                name = text(data, 'username', 80)
                participant = get_user_model().objects.filter(username=name, is_active=True).first()
                if not participant or teacher(participant) or participant.is_staff or participant.date_joined > c.ends_at:
                    return fail('Идэвхтэй суралцагчийн нэр оруулна уу.', 400)
                score = integer(data.get('score'), 0, p.points)
                penalty = integer(data.get('penalty'), 0, 43200)
                previous = ContestResult.objects.filter(problem=p, participant=participant.username).first()
                result, created = ContestResult.objects.update_or_create(problem=p, participant=participant.username,
                    defaults={'score':score,'penalty':penalty})
                audit(user, result, f'Teacher verified contest {c.pk}, {p.label}: ' +
                      (f'{previous.score}/{previous.penalty} -> ' if previous else '') + f'{score}/{penalty}',
                      ADDITION if created else CHANGE)
            return response({'contest': contest_card(c)})
    except ValueError as exc:
        return fail(str(exc))
